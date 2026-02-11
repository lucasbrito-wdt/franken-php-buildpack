<?php
// Minimal octane.php config for testing

return [
    'server' => env('OCTANE_SERVER', 'frankenphp'),
    'https' => false,
    'listeners' => [],
    'warm' => [],
    'flush' => [],
    'max_execution_time' => 30,
];
