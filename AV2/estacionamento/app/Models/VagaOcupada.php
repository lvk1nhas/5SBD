<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Carbon\Carbon;

class VagaOcupada extends Model
{
    use HasFactory;

    protected $fillable = ['vaga_id', 'placa', 'horario_entrada', 'horario _saida', 'preco'];

    protected $table = 'vaga_ocupada'; // O laravel pluraliza ai eu tenho que btoar isso p lembrar o nome certo da tabela

    // Relacionamento com o modelo Vaga

     /**
     * Método para calcular o preço com base na duração da ocupação
     */
    public function calcularPreco()
    {
        // Garantir que as datas estejam no formato correto
        $horaEntrada = Carbon::parse($this->horario_entrada);
        $horaSaida = $this->horario_saida ? Carbon::parse($this->horario_saida) : Carbon::now();

        // Calcular a duração em horas
        $duracaoHoras = max(1, $horaSaida->diffInHours($horaEntrada));

        return 10 * $duracaoHoras; // Preço base: 10 reais por hora
    }
    
  
        public function vaga()
        {
            return $this->belongsTo(Vaga::class, 'vaga_id');
        }
    

    
}
