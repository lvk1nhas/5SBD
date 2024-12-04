<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::table('pagamentos', function (Blueprint $table) {
            $table->string('placa')->nullable(); // Adiciona a coluna placa
        });
    }

    public function down()
    {
        Schema::table('pagamentos', function (Blueprint $table) {
            $table->dropColumn('placa'); // Remove a coluna placa caso o rollback seja feito
        });
    }
};
