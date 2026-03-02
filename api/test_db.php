<?php
header('Content-Type: application/json');

$results = [
    'environment' => [
        'is_vercel_env' => isset($_ENV['VERCEL']) || getenv('VERCEL') ? 'YES' : 'NO',
        'is_infinity_free' => (isset($_SERVER['SERVER_NAME']) && strpos($_SERVER['SERVER_NAME'], 'rf.gd') !== false) ? 'YES' : 'NO',
        'php_version' => phpversion(),
    ],
    'files' => [
        'db_exists' => file_exists('util/db.php') ? 'YES' : 'NO',
        'db_production_exists' => file_exists('util/db_production.php') ? 'YES' : 'NO',
    ],
    'connection_test' => null
];

try {
    if (isset($_ENV['VERCEL']) || getenv('VERCEL')) {
        $results['included_file'] = 'util/db_production.php';
        require_once 'util/db_production.php';
    }
    else {
        $results['included_file'] = 'util/db.php';
        require_once 'util/db.php';
    }

    if (isset($pdo)) {
        $results['connection_test'] = 'SUCCESS';
        // Test a simple query
        $stmt = $pdo->query("SELECT COUNT(*) FROM pelanggans");
        $results['table_test'] = [
            'pelanggans_count' => $stmt->fetchColumn()
        ];
    }
    else {
        $results['connection_test'] = 'FAILED (PDO variable not set)';
    }
}
catch (Exception $e) {
    $results['connection_test'] = 'ERROR: ' . $e->getMessage();
}

echo json_encode($results, JSON_PRETTY_PRINT);
?>
