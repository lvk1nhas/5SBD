<?php

use Illuminate\Database\Capsule\Manager as Capsule;

require 'vendor/autoload.php'; // Autoload das dependências instaladas pelo Composer

$capsule = new Capsule;

$capsule->addConnection([
    'driver'    => 'mysql',
    'host'      => 'localhost',
    'database'  => 'usuarios',
    'username'  => 'root',
    'password'  => '',
    'charset'   => 'utf8',
    'collation' => 'utf8_unicode_ci',
    'prefix'    => '',
]);

$capsule->setAsGlobal();
$capsule->bootEloquent();
