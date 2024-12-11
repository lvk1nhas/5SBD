--
-- Estrutura para tabela wl_clientes
---

CREATE TABLE wl_clientes (
  id int(11) NOT NULL,
  codigoComprador varchar(32) NOT NULL,
  nomeComprador varchar(100) NOT NULL,
  email varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- --------------------------------------------------------

--
-- Estrutura para tabela wl_compras
--

CREATE TABLE wl_compras (
  id int(11) NOT NULL,
  SKU varchar(20) NOT NULL,
  quantidade int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;



-- --------------------------------------------------------

--
-- Estrutura para tabela wl_entregas
--

CREATE TABLE wl_entregas (
  id int(11) NOT NULL,
  codigoPedido varchar(32) NOT NULL,
  endereco varchar(255) NOT NULL,
  CEP varchar(11) NOT NULL,
  UF varchar(2) NOT NULL,
  pais varchar(20) NOT NULL,
  valor float(5,2) NOT NULL DEFAULT 0.00
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- --------------------------------------------------------

--
-- Estrutura para tabela wl_estoque
--

CREATE TABLE wl_estoque (
  id int(11) NOT NULL,
  SKU varchar(20) NOT NULL,
  quantidade int(11) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- --------------------------------------------------------

--
-- Estrutura para tabela wl_itens_pedidos
--

CREATE TABLE wl_itens_pedidos (
  id int(11) NOT NULL,
  codigoPedido varchar(20) NOT NULL,
  SKU varchar(20) NOT NULL,
  quantidade int(11) NOT NULL,
  valor_unitario float(5,2) NOT NULL DEFAULT 0.00,
  status enum('aprovado','cancelado','pendente') NOT NULL DEFAULT 'pendente'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- --------------------------------------------------------

--
-- Estrutura para tabela wl_pedidos
--

CREATE TABLE wl_pedidos (
  id int(11) NOT NULL,
  codigoPedido varchar(32) NOT NULL,
  codigoComprador varchar(32) NOT NULL,
  dataPedido date NOT NULL,
  valor float(5,2) NOT NULL,
  status enum('aprovado','cancelado','pendente') NOT NULL DEFAULT 'pendente'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;



-- --------------------------------------------------------

--
-- Estrutura para tabela wl_produtos
--

CREATE TABLE wl_produtos (
  id int(11) NOT NULL,
  SKU varchar(20) NOT NULL,
  UPC varchar(20) NOT NULL,
  nomeProduto varchar(50) NOT NULL,
  valor float NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- --------------------------------------------------------

--
-- Estrutura para tabela wl_tempdata
--

CREATE TABLE wl_tempdata (
  codigoPedido varchar(30) NOT NULL,
  dataPedido date NOT NULL,
  SKU varchar(20) NOT NULL,
  UPC varchar(20) NOT NULL,
  nomeProduto varchar(100) NOT NULL,
  quantidade int(11) NOT NULL,
  valor float NOT NULL,
  frete int(11) NOT NULL,
  email varchar(200) NOT NULL,
  codigoComprador varchar(4) NOT NULL,
  nomeComprador varchar(50) NOT NULL,
  endereco varchar(255) NOT NULL,
  CEP varchar(11) NOT NULL,
  UF varchar(2) NOT NULL,
  pais varchar(15) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estrutura para tabela wl_tempdata_estoque
--

CREATE TABLE wl_tempdata_estoque (
  SKU varchar(20) NOT NULL,
  quantidade int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;




--
-- Índices de tabela wl_clientes
--
ALTER TABLE wl_clientes
  ADD PRIMARY KEY (id),
  ADD UNIQUE KEY codigoComprador (codigoComprador),
  ADD UNIQUE KEY email (email);

--
-- Índices de tabela wl_compras
--
ALTER TABLE wl_compras
  ADD PRIMARY KEY (id),
  ADD UNIQUE KEY SKU (SKU);

--
-- Índices de tabela wl_entregas
--
ALTER TABLE wl_entregas
  ADD PRIMARY KEY (id),
  ADD UNIQUE KEY codigoPedido (codigoPedido);

--
-- Índices de tabela wl_estoque
--
ALTER TABLE wl_estoque
  ADD PRIMARY KEY (id),
  ADD UNIQUE KEY SKU (SKU);

--
-- Índices de tabela wl_itens_pedidos
--
ALTER TABLE wl_itens_pedidos
  ADD PRIMARY KEY (id),
  ADD KEY FK_ItensPedidosCodigoComprador (codigoPedido),
  ADD KEY FK_ItensPedidosSKU (SKU);

--
-- Índices de tabela wl_pedidos
--
ALTER TABLE wl_pedidos
  ADD PRIMARY KEY (id),
  ADD UNIQUE KEY codigoPedido (codigoPedido),
  ADD KEY FK_PedidosComprador (codigoComprador);

--
-- Índices de tabela wl_produtos
--
ALTER TABLE wl_produtos
  ADD PRIMARY KEY (id),
  ADD UNIQUE KEY SKU (SKU),
  ADD UNIQUE KEY UPC (UPC);

--
-- AUTO_INCREMENT para tabelas despejadas
--

--
-- AUTO_INCREMENT de tabela wl_clientes
--
ALTER TABLE wl_clientes
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT de tabela wl_compras
--
ALTER TABLE wl_compras
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT de tabela wl_entregas
--
ALTER TABLE wl_entregas
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=512;

--
-- AUTO_INCREMENT de tabela wl_estoque
--
ALTER TABLE wl_estoque
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT de tabela wl_itens_pedidos
--
ALTER TABLE wl_itens_pedidos
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1024;

--
-- AUTO_INCREMENT de tabela wl_pedidos
--
ALTER TABLE wl_pedidos
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=512;

--
-- AUTO_INCREMENT de tabela wl_produtos
--
ALTER TABLE wl_produtos
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- Restrições para tabelas despejadas
--

--
-- Restrições para tabelas wl_compras
--
ALTER TABLE wl_compras
  ADD CONSTRAINT FK_ComprasSKU FOREIGN KEY (SKU) REFERENCES wl_produtos (SKU) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Restrições para tabelas wl_entregas
--
ALTER TABLE wl_entregas
  ADD CONSTRAINT FK_EntregasCodigoPedido FOREIGN KEY (codigoPedido) REFERENCES wl_pedidos (codigoPedido) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Restrições para tabelas wl_estoque
--
ALTER TABLE wl_estoque
  ADD CONSTRAINT FK_EstoqueSKU FOREIGN KEY (SKU) REFERENCES wl_produtos (SKU) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Restrições para tabelas wl_itens_pedidos
--
ALTER TABLE wl_itens_pedidos
  ADD CONSTRAINT FK_ItensPedidosCodigoComprador FOREIGN KEY (codigoPedido) REFERENCES wl_pedidos (codigoPedido) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT FK_ItensPedidosSKU FOREIGN KEY (SKU) REFERENCES wl_produtos (SKU) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Restrições para tabelas wl_pedidos
--
ALTER TABLE wl_pedidos
  ADD CONSTRAINT FK_PedidosComprador FOREIGN KEY (codigoComprador) REFERENCES wl_clientes (codigoComprador) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */; 
