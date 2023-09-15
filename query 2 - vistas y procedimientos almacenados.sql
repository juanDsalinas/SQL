Use neptunedb;
-------------------------------------------- 1 --------------------------------------------------------
create view VwProductoDetails as 
select p.idProducto, p.nombreProducto, c.idCategoria, c.nombreCategoria, dp.cantidad from producto as p inner join detalles_de_pedido as dp
on p.idProducto=dp.idProducto inner join categoria as c on p.idCategoria=c.idCategoria group by p.idProducto;

delimiter //
create procedure spProductDetails(in id int)
begin
	select nombreProducto, cantidad from VwProductoDetails where idCategoria = id;
end; 
//

call spProductDetails(1);

-------------------------------------------- 2 --------------------------------------------------------
create view VwDetailsEmpleado as
select e.nombre, e.apellidos, (2023-year(fechaNacimiento)) as edad, (dp.precioUnidad*dp.cantidad) as totalVentas from empleado as e inner join pedido as p on p.idEmpleado=e.idEmpleado
inner join detalles_de_pedido as dp on dp.idPedido=p.idPedido where e.idEmpleado=p.idEmpleado group by e.idEmpleado;

delimiter //
create procedure spDetailsEmpleado(in valor int)
begin
	select * from VwDetailsEmpleado where totalVentas>valor; 
end;
//

call spDetailsEmpleado(200);
-------------------------------------------- 3 --------------------------------------------------------

create view VwDetailsProduct as 
select c.nombreCategoria, p.nombreProducto, pro.idProveedor, pro.nombreEmpresa, p.cantidadPorUnidad from categoria as c
inner join producto as p on p.idCategoria=c.idCategoria
inner join proveedor as pro on p.idProveedor=pro.idProveedor;

select * from VwDetailsProduct;

delimiter //
create procedure spDetailsProduct(in id int)
begin
	select * from VwDetailsProduct where idProveedor=id;
end;
//

call spDetailsProduct(1);

-------------------------------------------- 4 --------------------------------------------------------
create view VwClienteDetails (idCliente, nombreEmpresa,totalPrecio,fechaPedido) as
select c.idCliente, c.nombreEmpresa, (dp.cantidad*dp.precioUnidad) as totalPrecio, Month(p.fechaPedido) from cliente as c inner join pedido as p on p.idCliente=c.idCliente
inner join detalles_de_pedido as dp on dp.idPedido=p.idPedido order by c.idCliente and  Month(p.fechaPedido);

drop view VwClienteDetails;

select * from VwClienteDetails;

delimiter //
create procedure ClienteDetails(in fechaInicial date, fechaFinal date)
begin	
	select * from VwClienteDetails where fechaPedido between fechaInicial and fechaFinal;
end;
//

call ClienteDetails(3,6);
-------------------------------------------- 5 --------------------------------------------------------
CREATE VIEW VistaPorcentajePago (codigoCliente,nombreCompania,porcentaje_pago)AS
SELECT
    IdCliente,
    NombreEmpresa,
    (totalPrecio / totalVentas) * 100 AS porcentaje_pago
FROM (
    SELECT
        vws.IdCliente,
        vws.NombreEmpresa,
        vws.totalPrecio,
        (SELECT SUM(totalPrecio) FROM VwClienteDetails) AS totalVentas
    FROM VwClienteDetails vws
) AS subconsulta;

DELIMITER //
CREATE PROCEDURE SP_ClientesPorcentajeMayor(IN porcentaje_mayor FLOAT)
BEGIN
    SELECT
        codigoCliente,
        nombreCompania,
        porcentaje_pago
    FROM
        VistaPorcentajePago
    WHERE
        porcentaje_pago > porcentaje_mayor;
END;
//
DELIMITER ;

CALL SP_ClientesPorcentajeMayor(0.01); -- Esto mostrará los clientes con un porcentaje de pago mayor al 30%

-------------------------------------------- 6 --------------------------------------------------------
CREATE VIEW vista_productoV2 AS 
SELECT * FROM producto WHERE PrecioUnidad > 20 
with check option; 

DELIMITER //
CREATE PROCEDURE spInsertarProducto(in id_Producto int,IN nombre_producto VARCHAR(80), IN precio_unidad FLOAT)
BEGIN
    INSERT INTO producto (idProducto,NombreProducto, PrecioUnidad)
    VALUES (id_Producto,nombre_producto, precio_unidad);
END;
//
DELIMITER ;

CALL spInsertarProducto(1010,'Suavitel', 30);

/*se realiza el registro pero nos devuelve una alerta ya que solo se inserta el id del producto y el nombre del producto*/

DELIMITER // 
CREATE PROCEDURE SP_modificarProduV2(codProducto int, precio float) 
BEGIN 
	SET @PrecioActual = (SELECT PrecioUnidad FROM vista_productoV2 WHERE idProducto = codProducto); 
    IF precio between @PrecioActual * 0.95 AND @PrecioActual * 1.05 THEN 
		UPDATE vista_productoV2 SET PrecioUnidad = precio WHERE idProducto = codProducto; 
	ELSE  
		signal sqlstate '45000' SET message_text = 'EL PRECIO NO PUEDE INCREMNETAR NI DRECREMENTAR MÁS DEL 5% DEL PRECIO ORIGINAL'; 
    END IF; 
END; 
//

call SP_modificarProduV2(4,23.0);
-------------------------------------------- 7 --------------------------------------------------------
-- El funcionamiento de la clausula distinct es muy sencillo, lo que busca esta clausula es permitir que en la consulta se eliminen duplicados
-- y de esta manera solo se mostraran aquellos datos que sean unicos
create view RegionesClienteView
as
select distinct Region from cliente
where Region is not null;

select * from RegionesClienteView;
-------------------------------------------- 8 --------------------------------------------------------
-- Procedimiento almacenado para inactivar o suspender productos 

DELIMITER //
create procedure SPSuspendeProductos(IN CodigoProducto int)
begin 
	-- variable de cantidades en pedido
    declare UnidadEnPedido int;
    -- variable de mensaje de error
    declare ErrorExistencias varchar (70);
    -- Asignacion de cantidad de existencias
    set UnidadEnPedido = (select UnidadesEnExistencia from producto where IdProducto = CodigoProducto);
    
    if UnidadEnPedido = 0 then 
		update producto 
        set Suspendido = 1
        where IdProducto = CodigoProducto
        ;
        select IdProducto, NombreProducto, Suspendido 
        from producto
        where IdProducto=CodigoProducto;
    else 
		set ErrorExistencias = 'La cantidad de existencias es mayor o menor a 0 y no se puede suspender';
		select ErrorExistencias;
	end if;
    
end; 
//

call SPSuspendeProductos(10);
