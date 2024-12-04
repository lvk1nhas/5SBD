<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Vaga extends Model
{
    use HasFactory;

    protected $fillable = ['tipo', 'status'];

    public function vagaOcupada()
    {
        return $this->hasMany(VagaOcupada::class, 'vaga_id');
    }
}
