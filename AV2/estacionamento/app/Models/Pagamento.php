<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Pagamento extends Model
{
    use HasFactory;

    protected $fillable = [
        'vaga_id',
        'preco',
        'placa',
        'status',
    
    ];

    /**
     * Relacionamento com a tabela VagaOcupada.
     */
        public function vaga()
        {
            return $this->belongsTo(Vaga::class, 'vaga_id'); // Associando ao campo 'vaga_id'
        }
    }
    

//O Lara verifica os campos permitidos na propriedade $fillable. Somente esses campos serão aceitos quando você usar métodos como create() ou update().
