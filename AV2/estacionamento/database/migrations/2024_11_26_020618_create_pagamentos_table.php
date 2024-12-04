<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('pagamentos', function (Blueprint $table) {
            $table->id();
            $table->foreignId('vaga_id')->constrained('vagas')->onDelete('cascade');  // Conectando com a tabela vagas
            $table->decimal('preco', 8, 2);
            $table->string('placa', 7);  // Adicionando a coluna placa
            $table->enum('status', ['pendente', 'pago']);
            $table->timestamps();
        });
    }
    
    public function down()
    {
        Schema::dropIfExists('pagamentos');
    }
    
};
