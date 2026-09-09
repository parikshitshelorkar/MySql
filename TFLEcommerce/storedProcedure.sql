DELIMITER //

CREATE PROCEDURE AddToCart(
    IN uid INT,
    IN pid INT,
    IN quantity INT,
    IN img VARCHAR(255)
)
BEGIN

    DECLARE cartid INT;
    DECLARE item_exists INT DEFAULT 0;
    DECLARE existing_cart_id INT DEFAULT NULL;
    DECLARE existing_quantity INT DEFAULT 0;
    DECLARE available_stock INT DEFAULT 0;

    -- Check whether user exists
    IF NOT EXISTS (
        SELECT 1
        FROM users
        WHERE id = uid
    ) THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'User does not exist';

    ELSE

        -- Get product stock
        SELECT stock
        INTO available_stock
        FROM products
        WHERE id = pid;

        -- Check whether product exists
        IF available_stock IS NULL THEN

            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Product does not exist';

        ELSEIF quantity <= 0 THEN

            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Quantity must be greater than zero';

        ELSE

            -- Check if user already has a cart
            SELECT cart_id
            INTO existing_cart_id
            FROM cart
            WHERE customer_id = uid
            LIMIT 1;

            -- Check if product already exists in user's cart
            SELECT COUNT(*)
            INTO item_exists
            FROM cart_items ci
            JOIN cart c
                ON ci.cart_id = c.cart_id
            WHERE c.customer_id = uid
              AND ci.product_id = pid;

            IF item_exists > 0 THEN

                -- Get current quantity
                SELECT ci.quantity
                INTO existing_quantity
                FROM cart_items ci
                JOIN cart c
                    ON ci.cart_id = c.cart_id
                WHERE c.customer_id = uid
                  AND ci.product_id = pid
                LIMIT 1;

                -- Check total quantity against stock
                IF existing_quantity + quantity > available_stock THEN

                    SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'Requested quantity exceeds available stock';

                ELSE

                    -- Increase existing quantity
                    UPDATE cart_items ci
                    JOIN cart c
                        ON ci.cart_id = c.cart_id
                    SET ci.quantity = ci.quantity + quantity
                    WHERE c.customer_id = uid
                      AND ci.product_id = pid;

                END IF;

            ELSE

                -- User already has a cart
                IF existing_cart_id IS NOT NULL THEN

                    SET cartid = existing_cart_id;

                ELSE

                    -- Create new cart
                    INSERT INTO cart(customer_id)
                    VALUES (uid);

                    SET cartid = LAST_INSERT_ID();

                END IF;

                -- Add product to cart
                INSERT INTO cart_items(
                    cart_id,
                    product_id,
                    quantity,
                    Itemimage
                )
                VALUES (
                    cartid,
                    pid,
                    quantity,
                    img
                );

            END IF;

        END IF;

    END IF;

END //

DELIMITER ;

CALL AddToCart(2,13,1,"/images/Fashion/tshirt.jpeg");



-- remove from cart
DELIMITER //
CREATE PROCEDURE RemoveFromCart(in pid int, in uid int, in qty int)
BEGIN
DECLARE available_quantity int; 
select quantity into available_quantity from cart_items where product_id = pid;

if not exists (select customer_id 
	from cart c
	join cart_items ci 
    on c.cart_id = ci.cart_id
    where ci.product_id = pid and c.customer_id = uid)
then SIGNAL SQLSTATE '45000'
	SET MESSAGE_TEXT = 'Requested Customer Cart does not exists!';
    
else if (available_quantity) is null
then 
    SIGNAL SQLSTATE '45000'
	 SET MESSAGE_TEXT = 'Item is not added';
     
else if available_quantity = qty
then 
    delete ci from cart_items ci
    join cart c on c.cart_id = ci.cart_id
    where ci.product_id = pid and c.customer_id = uid;
    
else if (available_quantity) < qty
	then SIGNAL SQLSTATE '45000'
	 SET MESSAGE_TEXT = 'Invalid input of quantity, quantity>available items';
else
	update cart_items set quantity = quantity - qty
	where product_id = pid;
    
end if;
end if;
end if;
end if;
END//
DELIMITER ;

CALL RemoveFromCart(4, 1, 3);



-- place order
DELIMITER //
CREATE PROCEDURE Place_Order
(
 IN userid INT,
 IN odate DATE,
 IN shipdate date,
 IN shipId int
 
)
BEGIN
		DECLARE total_price double;
		declare cartitemcount int;
        declare cartid int;
		declare count int;
        Declare orderid int;
         Declare stock int;
         DECLARE insufficient INT;
         
		set count=0;
		set total_price=0;
       
        set stock=0;
        
        -- get user cart
         SELECT cart_id INTO cartid
		FROM cart
		WHERE customer_id = userid
		LIMIT 1;

        -- get cart item count
		SET cartitemcount=(select count(ci.cart_item_id) 
						from cart_items ci
						join cart c on ci.cart_id=c.cart_id
						group by c.customer_id
						having c.customer_id=userid);
						

		-- get totalamount of cart items
		select sum(p.price*ci.quantity) into total_price
		from cart c
		join cart_items ci on ci.cart_id=c.cart_id
		join categoryproduct p on p.id=ci.product_id
		group by customer_id
		having c.customer_id=userid;
        


		-- insert order into table
		insert into orders(customer_id,order_date,total_amount,shipping_date,status,shipping_address_id) values (userid,odate, total_price,shipdate,"processing",shipid);
        
        -- get last inserted order
		set orderid=last_insert_id();
        
     -- insert cart_item into order_items table
			INSERT INTO order_items (order_id, item_id, quantity) select orderid, product_id,quantity from cart_items where cart_id=cartid;
		
         SELECT COUNT(*) INTO insufficient
		FROM cart_items ci
		JOIN categoryproduct p ON p.id = ci.product_id
		WHERE ci.cart_id = cartId
		AND p.stock < ci.quantity;

		IF insufficient > 0 THEN
			SIGNAL SQLSTATE '45000'
			SET MESSAGE_TEXT = 'Insufficient stock';
		ELSE
			UPDATE categoryproduct p
			JOIN cart_items ci ON p.id = ci.product_id
			SET p.stock = p.stock - ci.quantity
			WHERE ci.cart_id = cartId;
		END IF;
			

		-- Clear cart items
		DELETE FROM cart_items WHERE cart_id = cartid;

        -- Delete cart
		DELETE FROM cart WHERE cart_id = cartid;
END //
DELIMITER ;

CALL Place_Order(5, '2025-08-06', '2025-09-07', 9);

DELIMITER //
create procedure cancel_order(
In orderid int
)
begin
declare orderitem int;

             UPDATE categoryproduct p
			JOIN order_items oi ON p.id = oi.item_id
			SET p.stock = p.stock + oi.quantity
			WHERE oi.order_id = orderid;
            
	delete from order_items where order_id=orderid;
    delete from orders where id=orderid;
end
//

call cancel_order(44);

drop procedure AddToCart;
-- drop procedure RemoveFromCart;
-- drop procedure Place_Order;
-- drop procedure cancel_order;

SET SQL_SAFE_UPDATES = 0;
