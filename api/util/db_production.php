<?php
// JALUR DARURAT: Menghindari masalah Environment Variables Vercel
$host = getenv('DB_HOST') ?: '153.92.15.84';
$port = getenv('DB_PORT') ?: '3306';
$dbname = getenv('DB_NAME') ?: 'u915147866_db_hippams';
$username = getenv('DB_USER') ?: 'u915147866_hippams';
$password = getenv('DB_PASS') ?: 'Hippams2026!';

try {
    // Kita paksa menggunakan dsn tanpa variabel getenv
    $dsn = "mysql:host=$host;port=$port;dbname=$dbname;charset=utf8mb4";

    $options = [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ];

    $pdo = new PDO($dsn, $username, $password, $options);

}
catch (PDOException $e) {
    header('Content-Type: application/json');
    echo json_encode([
        "success" => false,
        "message" => "Gagal konek Hostinger: " . $e->getMessage(),
        "info" => "Cek kembali username/password/remote MySQL (%)"
    ]);
    exit();
}