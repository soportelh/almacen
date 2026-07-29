-- ============================================================
--  MOLINO — Panadería & Bebidas
--  Base de datos SQLite: inventario y clientes
--  Uso:  sqlite3 molino.sqlite < schema.sql
-- ============================================================

PRAGMA foreign_keys = ON;

DROP VIEW  IF EXISTS v_top_clientes;
DROP VIEW  IF EXISTS v_stock_bajo;
DROP VIEW  IF EXISTS v_valor_inventario;
DROP TABLE IF EXISTS venta_items;
DROP TABLE IF EXISTS ventas;
DROP TABLE IF EXISTS productos;
DROP TABLE IF EXISTS clientes;
DROP TABLE IF EXISTS categorias;

-- ------------------------------------------------------------
--  Catálogo
-- ------------------------------------------------------------
CREATE TABLE categorias (
  id     INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL UNIQUE
);

CREATE TABLE productos (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  sku           TEXT NOT NULL UNIQUE,
  nombre        TEXT NOT NULL,
  categoria_id  INTEGER NOT NULL REFERENCES categorias(id),
  unidad        TEXT NOT NULL DEFAULT 'unidad',
  precio        INTEGER NOT NULL,          -- precio de venta, CLP
  costo         INTEGER NOT NULL,          -- costo unitario, CLP
  stock         INTEGER NOT NULL DEFAULT 0,
  stock_minimo  INTEGER NOT NULL DEFAULT 0,
  activo        INTEGER NOT NULL DEFAULT 1,
  creado_en     TEXT NOT NULL DEFAULT (datetime('now')),
  CHECK (precio >= 0 AND costo >= 0 AND stock >= 0)
);
CREATE INDEX idx_productos_categoria ON productos(categoria_id);

-- ------------------------------------------------------------
--  Clientes
-- ------------------------------------------------------------
CREATE TABLE clientes (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre     TEXT NOT NULL,
  tipo       TEXT NOT NULL DEFAULT 'Persona' CHECK (tipo IN ('Empresa','Persona')),
  rut        TEXT UNIQUE,
  email      TEXT,
  telefono   TEXT,
  comuna     TEXT,
  direccion  TEXT,
  creado_en  TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ------------------------------------------------------------
--  Ventas (para métricas de compras por cliente)
-- ------------------------------------------------------------
CREATE TABLE ventas (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  cliente_id  INTEGER NOT NULL REFERENCES clientes(id),
  fecha       TEXT NOT NULL DEFAULT (datetime('now')),
  estado      TEXT NOT NULL DEFAULT 'Pagada' CHECK (estado IN ('Pagada','Pendiente','Anulada'))
);
CREATE INDEX idx_ventas_cliente ON ventas(cliente_id);

CREATE TABLE venta_items (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  venta_id     INTEGER NOT NULL REFERENCES ventas(id) ON DELETE CASCADE,
  producto_id  INTEGER NOT NULL REFERENCES productos(id),
  cantidad     INTEGER NOT NULL CHECK (cantidad > 0),
  precio_unit  INTEGER NOT NULL
);
CREATE INDEX idx_items_venta ON venta_items(venta_id);

-- ------------------------------------------------------------
--  Vistas de apoyo para el dashboard
-- ------------------------------------------------------------
CREATE VIEW v_stock_bajo AS
  SELECT p.sku, p.nombre, c.nombre AS categoria, p.stock, p.stock_minimo,
         (p.stock_minimo - p.stock) AS faltan
  FROM productos p JOIN categorias c ON c.id = p.categoria_id
  WHERE p.activo = 1 AND p.stock < p.stock_minimo
  ORDER BY faltan DESC;

CREATE VIEW v_valor_inventario AS
  SELECT c.nombre AS categoria,
         COUNT(*)                AS productos,
         SUM(p.stock)            AS unidades,
         SUM(p.stock * p.costo)  AS valor_costo
  FROM productos p JOIN categorias c ON c.id = p.categoria_id
  WHERE p.activo = 1
  GROUP BY c.nombre;

CREATE VIEW v_top_clientes AS
  SELECT cl.id, cl.nombre, cl.tipo, cl.comuna,
         COALESCE(SUM(vi.cantidad * vi.precio_unit), 0) AS total_compras
  FROM clientes cl
  LEFT JOIN ventas v      ON v.cliente_id = cl.id AND v.estado = 'Pagada'
  LEFT JOIN venta_items vi ON vi.venta_id = v.id
  GROUP BY cl.id
  ORDER BY total_compras DESC;

-- ============================================================
--  DATOS DE EJEMPLO
-- ============================================================
INSERT INTO categorias (id, nombre) VALUES
  (1,'Pan'), (2,'Bebidas'), (3,'Dulce');

INSERT INTO productos (sku, nombre, categoria_id, unidad, precio, costo, stock, stock_minimo) VALUES
  ('PAN-001','Marraqueta',              1,'1 kg',   1890,1100, 48, 30),
  ('PAN-002','Hallulla',                1,'1 kg',   1790,1050, 22, 30),
  ('PAN-003','Pan de masa madre',       1,'700 g',  3990,2400, 15, 12),
  ('PAN-004','Baguette artesanal',      1,'unidad', 1290, 700, 60, 20),
  ('PAN-005','Ciabatta',                1,'unidad', 2190,1200, 27, 20),
  ('DUL-001','Croissant de mantequilla',3,'unidad', 1190, 620,  8, 15),
  ('DUL-002','Berlín con crema',        3,'unidad', 1390, 720, 34, 15),
  ('BEB-001','Jugo de naranja',         2,'1 L',    2290,1400, 40, 24),
  ('BEB-002','Café latte frío',         2,'350 ml', 2490,1500, 12, 18),
  ('BEB-003','Agua mineral',            2,'1.5 L',   990, 500,120, 40),
  ('BEB-004','Bebida cola',             2,'1.5 L',  1590, 900, 55, 30);

INSERT INTO clientes (nombre, tipo, rut, email, telefono, comuna) VALUES
  ('Panadería Central Ltda','Empresa','76.482.113-9','compras@central.cl','+56 2 2345 6789','Santiago Centro'),
  ('Almacén Doña Rosa',      'Empresa','77.019.884-2','donarosa@gmail.com','+56 9 8123 4567','Ñuñoa'),
  ('Café Vereda',            'Empresa','78.221.550-K','hola@cafevereda.cl','+56 9 7654 3210','Providencia'),
  ('Minimarket El Sol',      'Empresa','76.998.201-4','elsol@minimarket.cl','+56 9 6543 2109','Maipú'),
  ('Juan Pérez',             'Persona','12.345.678-5','juanp@correo.cl','+56 9 5432 1098','La Florida'),
  ('Catalina Rojas',         'Persona','16.789.012-3','crojas@correo.cl','+56 9 4321 0987','Las Condes');

-- Ventas de ejemplo (para v_top_clientes)
INSERT INTO ventas (id, cliente_id, estado) VALUES
  (1,1,'Pagada'),(2,1,'Pagada'),(3,2,'Pagada'),
  (4,3,'Pagada'),(5,4,'Pagada'),(6,5,'Pagada'),(7,6,'Pagada');

INSERT INTO venta_items (venta_id, producto_id, cantidad, precio_unit) VALUES
  (1, 1, 120, 1890),(1, 4,  40, 1290),
  (2, 8,  30, 2290),(2,10,  60,  990),
  (3, 2,  50, 1790),(3, 6,  24, 1390),
  (4, 3,  18, 3990),(4, 7,  20, 2290),
  (5, 5,  15, 2190),(5,11,  30, 1590),
  (6, 6,   6, 1390),(6, 9,   4, 2490),
  (7, 4,  10, 1290),(7, 3,   3, 3990);
