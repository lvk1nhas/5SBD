<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('vagas', function (Blueprint $table) {
            $table->id();  // id autoincremental
            $table->enum('tipo', ['comum', 'deficiente']); // tipo da vaga
            $table->enum('status', ['disponivel', 'ocupada', 'pendente'])->default('disponivel');
            $table->timestamps(); // created_at e updated_at
        });
    }
    

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('vagas');
    }
};
