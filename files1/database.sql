-- ============================================================
-- database.sql — LezzetKapı Yemek Sipariş Sistemi
-- Veritabanı Şema Taslağı
-- -------------------------------------------------------
-- Bu dosya yalnızca tasarım amaçlıdır; çalıştırılması
-- gerekmez. Gerçek bir projede MySQL / PostgreSQL ile
-- kullanılabilir.
-- ============================================================

-- ============================================================
-- Mevcut tablolar varsa önce sil (sıfırdan başlamak için)
-- ============================================================
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS menu_items;
DROP TABLE IF EXISTS restaurants;
DROP TABLE IF EXISTS users;


-- ============================================================
-- 1. KULLANICILAR (users)
--    Sisteme kayıtlı tüm kullanıcıları tutar.
--    rol: 'musteri' | 'restoran_sahibi' | 'admin'
-- ============================================================
CREATE TABLE users (
    kullanici_id   INT           AUTO_INCREMENT PRIMARY KEY,
    ad             VARCHAR(80)   NOT NULL,
    soyad          VARCHAR(80)   NOT NULL,
    eposta         VARCHAR(150)  NOT NULL UNIQUE,
    sifre_hash     VARCHAR(255)  NOT NULL,          -- Şifre bcrypt ile hashlenir
    telefon        VARCHAR(20),
    adres          TEXT,
    rol            ENUM('musteri', 'restoran_sahibi', 'admin')
                                 NOT NULL DEFAULT 'musteri',
    aktif          BOOLEAN       NOT NULL DEFAULT TRUE,
    kayit_tarihi   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    guncelleme     DATETIME      ON UPDATE CURRENT_TIMESTAMP
);

-- Örnek Veri
INSERT INTO users (ad, soyad, eposta, sifre_hash, telefon, adres, rol) VALUES
('Ayşe',  'Kaya',    'ayse@ornek.com',  '$2b$12$...', '0532 111 22 33', 'Kadıköy, İstanbul',  'musteri'),
('Mehmet','Demir',   'mehmet@ornek.com','$2b$12$...', '0533 444 55 66', 'Beşiktaş, İstanbul', 'musteri'),
('Admin', 'Kullanıcı','admin@lezzetkapi.com','$2b$12$...', NULL, NULL,  'admin');


-- ============================================================
-- 2. RESTORANLAR (restaurants)
--    Platforma kayıtlı restoranların bilgileri.
-- ============================================================
CREATE TABLE restaurants (
    restoran_id      INT           AUTO_INCREMENT PRIMARY KEY,
    sahip_id         INT           NOT NULL,               -- users.kullanici_id
    restoran_adi     VARCHAR(150)  NOT NULL,
    kategori         VARCHAR(100)  NOT NULL,               -- 'pizza', 'burger', vb.
    aciklama         TEXT,
    adres            TEXT          NOT NULL,
    sehir            VARCHAR(80)   NOT NULL DEFAULT 'İstanbul',
    telefon          VARCHAR(20),
    logo_url         VARCHAR(255),
    ortalama_puan    DECIMAL(3,2)  DEFAULT 0.00,           -- 0.00 – 5.00
    teslimat_suresi  VARCHAR(30),                          -- '25-35 dk'
    teslimat_ucreti  DECIMAL(8,2)  DEFAULT 0.00,
    min_siparis      DECIMAL(8,2)  DEFAULT 0.00,
    acik_mi          BOOLEAN       DEFAULT TRUE,
    olusturma        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (sahip_id) REFERENCES users(kullanici_id)
);

INSERT INTO restaurants (sahip_id, restoran_adi, kategori, aciklama, adres, teslimat_suresi, teslimat_ucreti, min_siparis) VALUES
(1, 'Bella Italia',    'pizza',   'Otantik İtalyan pizzaları.',         'Bağcılar, İstanbul',  '25-35 dk', 12.00, 80.00),
(1, 'Burger Bros',     'burger',  'El yapımı dev burgerler.',           'Şişli, İstanbul',     '20-30 dk',  0.00, 60.00),
(2, 'Osmanlı Sofrası', 'türk',    'Geleneksel Türk mutfağının tadı.',   'Fatih, İstanbul',     '30-45 dk', 10.00,100.00),
(2, 'Sushi Zen',       'suşi',    'Taze Japon lezzetleri.',             'Beşiktaş, İstanbul',  '40-55 dk', 20.00,150.00);


-- ============================================================
-- 3. MENÜ ÜRÜNLERİ (menu_items)
--    Her restorana ait menü kalemleri.
-- ============================================================
CREATE TABLE menu_items (
    urun_id        INT            AUTO_INCREMENT PRIMARY KEY,
    restoran_id    INT            NOT NULL,
    kategori       VARCHAR(100)   NOT NULL,   -- 'Pizzalar', 'Burgerler', vb.
    ad             VARCHAR(150)   NOT NULL,
    aciklama       TEXT,
    fiyat          DECIMAL(10,2)  NOT NULL,
    resim_url      VARCHAR(255),
    stokta_var     BOOLEAN        DEFAULT TRUE,
    sira           INT            DEFAULT 0,  -- Menüdeki sıralama
    olusturma      DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    guncelleme     DATETIME       ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (restoran_id) REFERENCES restaurants(restoran_id)
);

INSERT INTO menu_items (restoran_id, kategori, ad, aciklama, fiyat) VALUES
(1, 'Pizzalar', 'Margherita',         'Domates sosu, mozzarella, fesleğen',        129.00),
(1, 'Pizzalar', 'Pepperoni',          'Domates sosu, pepperoni, mozzarella',        149.00),
(1, 'Makarnalar','Spaghetti Carbonara','Yumurta, pancetta, parmesan',              119.00),
(2, 'Burgerler','Classic Cheeseburger','150g köfte, cheddar, marul, domates',      109.00),
(2, 'Burgerler','BBQ Bacon Burger',   'Pastırmalı, BBQ soslu, soğan halkası',      139.00),
(3, 'Kebaplar', 'Adana Kebap',        'Acılı kıyma kebabı, lavaş, közlenmiş biber',149.00),
(4, 'Suşi & Maki','Salmon Maki (8 parça)','Somon, avokado, salatalık',            149.00);


-- ============================================================
-- 4. SİPARİŞLER (orders)
--    Kullanıcıların verdiği siparişlerin ana kaydı.
--    durum: 'beklemede' | 'onaylandi' | 'hazirlaniyor' | 'kuryede' | 'teslim_edildi' | 'iptal'
-- ============================================================
CREATE TABLE orders (
    siparis_id       INT            AUTO_INCREMENT PRIMARY KEY,
    kullanici_id     INT            NOT NULL,
    restoran_id      INT            NOT NULL,
    teslimat_adresi  TEXT           NOT NULL,
    durum            ENUM(
                       'beklemede',
                       'onaylandi',
                       'hazirlaniyor',
                       'kuryede',
                       'teslim_edildi',
                       'iptal'
                     )              NOT NULL DEFAULT 'beklemede',
    ara_toplam       DECIMAL(10,2)  NOT NULL,
    teslimat_ucreti  DECIMAL(10,2)  NOT NULL DEFAULT 0.00,
    indirim          DECIMAL(10,2)  NOT NULL DEFAULT 0.00,
    genel_toplam     DECIMAL(10,2)  NOT NULL,   -- ara_toplam + teslimat - indirim
    promo_kodu       VARCHAR(50),
    notlar           TEXT,                       -- Müşteri özel notları
    siparis_tarihi   DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    guncelleme       DATETIME       ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (kullanici_id) REFERENCES users(kullanici_id),
    FOREIGN KEY (restoran_id)  REFERENCES restaurants(restoran_id)
);

INSERT INTO orders (kullanici_id, restoran_id, teslimat_adresi, durum, ara_toplam, teslimat_ucreti, genel_toplam) VALUES
(1, 1, 'Kadıköy, İstanbul', 'teslim_edildi', 278.00, 12.00, 290.00),
(2, 2, 'Beşiktaş, İstanbul','hazirlaniyor',  248.00,  0.00, 248.00);


-- ============================================================
-- 5. SİPARİŞ KALEMLERİ (order_items)
--    Her siparişin hangi ürünlerden oluştuğunu tutar.
-- ============================================================
CREATE TABLE order_items (
    kalem_id       INT            AUTO_INCREMENT PRIMARY KEY,
    siparis_id     INT            NOT NULL,
    urun_id        INT            NOT NULL,
    adet           INT            NOT NULL DEFAULT 1,
    birim_fiyat    DECIMAL(10,2)  NOT NULL,   -- Sipariş anındaki fiyat (değişebilir)
    toplam_fiyat   DECIMAL(10,2)  NOT NULL,   -- adet × birim_fiyat
    ozel_not       VARCHAR(255),              -- 'Soğansız', 'Acısız', vb.

    FOREIGN KEY (siparis_id) REFERENCES orders(siparis_id),
    FOREIGN KEY (urun_id)    REFERENCES menu_items(urun_id)
);

INSERT INTO order_items (siparis_id, urun_id, adet, birim_fiyat, toplam_fiyat) VALUES
(1, 1, 1, 129.00, 129.00),   -- Margherita
(1, 3, 1, 119.00, 119.00),   -- Spaghetti Carbonara
(1, 7, 2, 149.00, 298.00),   -- 2× Salmon Maki (farklı restoran örnek değil, sadece demo)
(2, 4, 2, 109.00, 218.00),   -- 2× Classic Cheeseburger
(2, 5, 1, 139.00, 139.00);   -- BBQ Bacon Burger


-- ============================================================
-- 6. ÖDEMELER (payments)
--    Her siparişe ait ödeme kaydı.
--    yontem: 'kredi_karti' | 'nakit' | 'dijital_cuzdan'
--    durum:  'beklemede' | 'tamamlandi' | 'basarisiz' | 'iade_edildi'
-- ============================================================
CREATE TABLE payments (
    odeme_id        INT            AUTO_INCREMENT PRIMARY KEY,
    siparis_id      INT            NOT NULL UNIQUE,        -- Her sipariş tek ödeme
    tutar           DECIMAL(10,2)  NOT NULL,
    yontem          ENUM('kredi_karti', 'nakit', 'dijital_cuzdan')
                                   NOT NULL DEFAULT 'kredi_karti',
    durum           ENUM('beklemede', 'tamamlandi', 'basarisiz', 'iade_edildi')
                                   NOT NULL DEFAULT 'beklemede',
    islem_kodu      VARCHAR(100),                          -- Ödeme sağlayıcı referans kodu
    son_dort_hane   CHAR(4),                               -- Kart son 4 hanesi (güvenli saklama)
    odeme_tarihi    DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (siparis_id) REFERENCES orders(siparis_id)
);

INSERT INTO payments (siparis_id, tutar, yontem, durum, islem_kodu) VALUES
(1, 290.00, 'kredi_karti', 'tamamlandi', 'TXN-A1B2C3D4'),
(2, 248.00, 'dijital_cuzdan', 'beklemede', NULL);


-- ============================================================
-- YARDIMCI SORGULAR (Örnek Kullanım)
-- ============================================================

-- Belirli bir siparişin tüm kalemlerini getir:
-- SELECT oi.*, mi.ad AS urun_adi
-- FROM order_items oi
-- JOIN menu_items mi ON oi.urun_id = mi.urun_id
-- WHERE oi.siparis_id = 1;

-- Bir kullanıcının tüm siparişlerini getir:
-- SELECT o.siparis_id, r.restoran_adi, o.durum, o.genel_toplam, o.siparis_tarihi
-- FROM orders o
-- JOIN restaurants r ON o.restoran_id = r.restoran_id
-- WHERE o.kullanici_id = 1
-- ORDER BY o.siparis_tarihi DESC;

-- En popüler ürünleri bul:
-- SELECT mi.ad, SUM(oi.adet) AS toplam_satis
-- FROM order_items oi
-- JOIN menu_items mi ON oi.urun_id = mi.urun_id
-- GROUP BY oi.urun_id
-- ORDER BY toplam_satis DESC
-- LIMIT 10;

-- ============================================================
-- Dosya sonu — LezzetKapı Veritabanı Taslağı
-- ============================================================
