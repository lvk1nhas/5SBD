DELIMITER $$

CREATE DEFINER=root@localhost PROCEDURE ProcessarItensPedidos ()   
BEGIN
    -- Declarando as variáveis no início da procedure
    DECLARE v_codigoPedido INT;
    DECLARE v_codigoProduto VARCHAR(20);
    DECLARE v_quantidade INT;
    DECLARE pronta INT DEFAULT 0;  -- Indica se o cursor já processou todos os registros
    DECLARE estoqueDisponivel INT; -- Declaração da variável de estoque
    DECLARE quantidadePendente INT; -- Declaração da variável para a quantidade total pendente do produto
    
    -- Cursor para selecionar os itens dos pedidos
    DECLARE cursor_itens CURSOR FOR 
    SELECT codigoPedido, SKU, quantidade 
    FROM wl_itens_pedidos
    WHERE status = 'pendente';  -- Apenas itens pendentes serão processados
    
    -- Handler para quando não houver mais registros no cursor
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET pronta = 1;

    -- Início da transação
    START TRANSACTION;

    -- Abrindo o cursor de itens
    OPEN cursor_itens;

    itens_loop: LOOP
        -- Buscando os dados do cursor
        FETCH cursor_itens INTO v_codigoPedido, v_codigoProduto, v_quantidade;

        IF pronta THEN
            LEAVE itens_loop;
        END IF;

        -- Calcula a quantidade total pendente do produto no estoque
        SELECT SUM(quantidade) INTO quantidadePendente
        FROM wl_itens_pedidos 
        WHERE SKU = v_codigoProduto AND status = 'pendente';

        -- Verifica a quantidade total do item no estoque
        SELECT quantidade INTO estoqueDisponivel
        FROM wl_estoque
        WHERE SKU = v_codigoProduto
        FOR UPDATE;

        -- Verifica se o estoque disponível é suficiente para todos os itens pendentes
        IF quantidadePendente <= estoqueDisponivel THEN
            -- Aprova todos os itens pendentes para esse produto
            UPDATE wl_itens_pedidos 
            SET status = 'aprovado' 
            WHERE SKU = v_codigoProduto AND status = 'pendente';
            
        ELSE
            -- Marca todos os itens pendentes desse produto como pendentes
            UPDATE wl_itens_pedidos 
            SET status = 'pendente' 
            WHERE SKU = v_codigoProduto AND status = 'pendente';

            -- Verifica se o item precisa ser comprado
            IF EXISTS (SELECT 1 FROM wl_compras WHERE SKU = v_codigoProduto) THEN
                UPDATE wl_compras 
                SET quantidade = quantidade + v_quantidade 
                WHERE SKU = v_codigoProduto;
            ELSE
                INSERT INTO wl_compras (SKU, quantidade) 
                VALUES (v_codigoProduto, v_quantidade);
            END IF;
        END IF;
    END LOOP;

    -- Fechando o cursor de itens
    CLOSE cursor_itens;

    -- Commit da transação
    COMMIT;

END$$

DELIMITER ;
