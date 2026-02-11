<?php
// Simulates a Laravel Octane public/index.php entry point

echo "<h1>Laravel Octane + FrankenPHP on Heroku</h1>";
echo "<p>Server: " . ($_SERVER['SERVER_SOFTWARE'] ?? 'unknown') . "</p>";
echo "<p>PHP Version: " . phpversion() . "</p>";
echo "<p>Port: " . ($_SERVER['SERVER_PORT'] ?? getenv('PORT') ?: 'unknown') . "</p>";
echo "<p>Octane Server: " . (getenv('OCTANE_SERVER') ?: 'frankenphp') . "</p>";
echo "<p>Time: " . date('Y-m-d H:i:s') . "</p>";
