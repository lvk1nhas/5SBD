<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::dropIfExists('pagamentos');
    }
    
    public function down()
    {
        Schema::create('pagamentos', function (Blueprint $table) {
            $table->id();
            $table->foreignId('vaga_id')->constrained()->onDelete('cascade');  // Aqui você vai ter a vaga_id como chave estrangeira
            $table->decimal('preco', 8, 2);
            $table->enum('status', ['pendente', 'pago']);
            $table->timestamps();
        });
    }
    
};
