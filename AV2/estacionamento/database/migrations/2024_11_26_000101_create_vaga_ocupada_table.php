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
        Schema::create('vaga_ocupada', function (Blueprint $table) {
            $table->id(); // id autoincremental
            $table->foreignId('vaga_id')->constrained()->onDelete('cascade'); // relacionamento com a tabela vagas
            $table->string('placa'); // placa do carro
            $table->timestamp('horario_entrada'); // horário da entrada
            $table->timestamp('horario_saida')->nullable(); // horário da saída (pode ser nulo enquanto a vaga estiver ocupada)
            $table->decimal('preco', 8, 2); // preço a ser pago
            $table->timestamps();
        });
    }
    

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('vaga_ocupada');
    }
};
