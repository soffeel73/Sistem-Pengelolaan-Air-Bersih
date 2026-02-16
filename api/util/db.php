<?php
// Smart Air Desa - Database Connection
// Auto-detect environment: Vercel (production) vs XAMPP (local)

$isProduction = isset($_ENV['VERCEL']) || getenv('VERCEL');

if ($isProduction) {
    // Production: Hostinger Remote MySQL
    $host = '153.92.15.84';
    $port = '3306';
    $dbname = 'u915147866_db_hippams';
    $username = 'u915147866_hippams';
    $password = 'Hippams2026!';
    $dsn = "mysql:host=$host;port=$port;dbname=$dbname;charset=utf8mb4";
}
else {
    // Local: XAMPP MySQL
    $dsn = "mysql:host=localhost;dbname=smart_air_desa;charset=utf8mb4";
    $username = 'root';
    $password = '';
}

try {
    $pdo = new PDO($dsn, $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);
}
catch (PDOException $e) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode([
        'success' => false,
        'message' => 'Database connection failed: ' . ($isProduction ? 'Production DB error' : $e->getMessage())
    ]);
    exit();
}
?>
