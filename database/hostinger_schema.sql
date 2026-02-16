-- ============================================================
-- HOSTINGER DATABASE SCHEMA: u915147866_db_hippams
-- Adapted from smart_air_desa schema for Hostinger deployment
-- ============================================================

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";

-- 1. Table: pelanggans
CREATE TABLE IF NOT EXISTS `pelanggans` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `customer_id` VARCHAR(50) NOT NULL UNIQUE COMMENT 'ID Pelanggan (e.g. HPM00001)',
  `name` VARCHAR(255) NOT NULL,
  `phone` VARCHAR(20) NOT NULL,
  `address` TEXT NOT NULL,
  `type` ENUM('R1', 'R2', 'N1', 'S1') NOT NULL COMMENT 'Golongan Tarif',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_customer_id (customer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2. Table: input_meters
CREATE TABLE IF NOT EXISTS `input_meters` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `pelanggan_id` INT NOT NULL,
  `period_year` INT NOT NULL,
  `period_month` INT NOT NULL,
  `meter_awal` INT DEFAULT 0,
  `meter_akhir` INT NOT NULL,
  `jumlah_pakai` INT NOT NULL,
  `total_biaya` DECIMAL(15,2) NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_pelanggan_period (pelanggan_id, period_year, period_month),
  CONSTRAINT fk_input_meters_pelanggan FOREIGN KEY (pelanggan_id) REFERENCES pelanggans(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. Table: tagihans
CREATE TABLE IF NOT EXISTS `tagihans` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `pelanggan_id` INT NOT NULL,
  `input_meter_id` INT NOT NULL,
  `month` VARCHAR(7) NOT NULL COMMENT 'Format: YYYY-MM',
  `initial_meter` INT DEFAULT 0,
  `final_meter` INT NOT NULL,
  `usage_amount` INT NOT NULL,
  `amount` DECIMAL(15,2) NOT NULL COMMENT 'Biaya pemakaian bulan ini',
  `tunggakan` DECIMAL(15,2) DEFAULT 0.00 COMMENT 'Akumulasi tunggakan sebelumnya',
  `total_tagihan` DECIMAL(15,2) NOT NULL COMMENT 'Amount + Tunggakan',
  `status` ENUM('paid', 'unpaid') DEFAULT 'unpaid',
  `paid_at` DATETIME DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_tagihan_pelanggan (pelanggan_id),
  INDEX idx_tagihan_status (status),
  CONSTRAINT fk_tagihans_pelanggan FOREIGN KEY (pelanggan_id) REFERENCES pelanggans(id) ON DELETE CASCADE,
  CONSTRAINT fk_tagihans_input_meter FOREIGN KEY (input_meter_id) REFERENCES input_meters(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. Table: transaksis
CREATE TABLE IF NOT EXISTS `transaksis` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `tagihan_id` INT DEFAULT NULL COMMENT 'Link to tagihan if applicable',
  `tipe` ENUM('pemasukan', 'pengeluaran') NOT NULL,
  `nama` VARCHAR(255) NOT NULL,
  `kategori` VARCHAR(100) NOT NULL,
  `nominal` DECIMAL(15,2) NOT NULL,
  `tanggal` DATE NOT NULL,
  `keterangan` TEXT NULL,
  `period_year` INT NOT NULL,
  `period_month` INT NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_period (period_year, period_month),
  INDEX idx_tipe (tipe),
  INDEX idx_tanggal (tanggal),
  INDEX idx_kategori (kategori)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. Table: keluhans
CREATE TABLE IF NOT EXISTS `keluhans` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `nama_lengkap` VARCHAR(255) NOT NULL,
  `no_hpm` VARCHAR(50) NOT NULL,
  `kategori` ENUM('Pipa Bocor', 'Air Tidak Mengalir', 'Meteran Rusak', 'Kesalahan Tagihan', 'Kualitas Air', 'Lainnya') NOT NULL,
  `detail_laporan` TEXT NOT NULL,
  `foto_bukti` VARCHAR(500) NULL,
  `no_whatsapp` VARCHAR(20) NOT NULL,
  `status` ENUM('Menunggu', 'Diproses', 'Selesai') DEFAULT 'Menunggu',
  `catatan_admin` TEXT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_no_hpm (no_hpm),
  INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 6. Table: beritas
CREATE TABLE IF NOT EXISTS `beritas` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `judul` VARCHAR(255) NOT NULL,
  `foto_url` VARCHAR(500),
  `ringkasan` TEXT,
  `isi_berita` LONGTEXT,
  `tanggal_publish` DATE,
  `status` ENUM('draft', 'published') DEFAULT 'published',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 7. Table: pengumumans
CREATE TABLE IF NOT EXISTS `pengumumans` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `teks` VARCHAR(500) NOT NULL,
  `status` ENUM('aktif', 'non-aktif') DEFAULT 'aktif',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 8. Table: pengurus
CREATE TABLE IF NOT EXISTS `pengurus` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `nama` VARCHAR(100) NOT NULL,
    `jabatan` VARCHAR(100) NOT NULL,
    `foto_url` VARCHAR(255) DEFAULT NULL,
    `urutan` INT DEFAULT 0,
    `is_active` TINYINT(1) DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 9. Table: galeris
CREATE TABLE IF NOT EXISTS `galeris` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `image_path` VARCHAR(255) NOT NULL,
    `judul` VARCHAR(255) DEFAULT NULL,
    `caption` TEXT DEFAULT NULL,
    `kategori` VARCHAR(100) DEFAULT 'Kegiatan',
    `is_active` TINYINT(1) DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

COMMIT;
