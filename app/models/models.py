# Importa las librerías necesarias.
# `List` y `Optional` de `typing` se usan para anotaciones de tipo.
# `SQLModel`, `Field` y `Relationship` se usan para definir los modelos de datos y sus relaciones.
from typing import List, Optional
from sqlmodel import Field, Relationship, SQLModel

class User(SQLModel, table=True):
    """
    Define el modelo para la tabla 'user'. 
    Representa a un usuario en el sistema.
    """
    # El atributo `table=True` indica a SQLModel que cree una tabla para esta clase.
    
    id: Optional[int] = Field(default=None, primary_key=True)
    # `id`: La clave primaria de la tabla. Es opcional al crear una instancia,
    # ya que la base de datos la generará automáticamente.

    username: str = Field(index=True, unique=True)
    # `username`: Nombre de usuario del usuario. Es único y se crea un índice
    # para búsquedas más rápidas.

    password: str
    # `password`: La contraseña del usuario.

    role: str = "customer"
    # `role`: El rol del usuario, con un valor por defecto de "customer".
    # Esto es útil para diferenciar entre roles como "administrador" o "cliente".

    reviews: List["Review"] = Relationship(back_populates="user")
    # `reviews`: Una relación que indica que un usuario puede tener múltiples reseñas.
    # El `back_populates` establece la conexión bidireccional con el atributo 'user' 
    # en el modelo `Review`.


class Category(SQLModel, table=True):
    """
    Define el modelo para la tabla 'category'. 
    Representa las categorías de productos.
    """
    id: Optional[int] = Field(default=None, primary_key=True)
    # `id`: La clave primaria de la tabla.

    name: str = Field(index=True, unique=True)
    # `name`: El nombre de la categoría (ej. "Electrónica"). Es único y se indexa.

    products: List["Product"] = Relationship(back_populates="category")
    # `products`: Una relación que indica que una categoría puede tener múltiples productos.
    # Conecta con el atributo 'category' en el modelo `Product`.


class Product(SQLModel, table=True):
    """
    Define el modelo para la tabla 'product'.
    Representa los productos que se venden.
    """
    id: Optional[int] = Field(default=None, primary_key=True)
    # `id`: La clave primaria del producto.

    name: str = Field(index=True)
    # `name`: El nombre del producto. Se indexa para búsquedas eficientes.

    description: str
    # `description`: La descripción del producto.

    price: float
    # `price`: El precio del producto.

    category_id: int = Field(foreign_key="category.id")
    # `category_id`: Clave foránea que vincula este producto a una categoría específica.

    category: Category = Relationship(back_populates="products") 
    # `category`: Una relación que permite acceder a los detalles de la categoría a 
    # la que pertenece el producto.

    reviews: List["Review"] = Relationship(back_populates="products")
    # `reviews`: Relación que indica que un producto puede tener múltiples reseñas.


class Review(SQLModel, table=True):
    """
    Define el modelo para la tabla 'review'.
    Representa las reseñas que los usuarios escriben sobre los productos.
    """
    id: Optional[int] = Field(default=None, primary_key=True)
    # `id`: La clave primaria de la reseña.

    text: str
    # `text`: El contenido del texto de la reseña.

    rating: int
    # `rating`: La calificación del producto (por ejemplo, de 1 a 5 estrellas).

    user_id: int = Field(foreign_key="user.id")
    # `user_id`: Clave foránea que conecta la reseña con un usuario específico.

    user: User = Relationship(back_populates="reviews")
    # `user`: Una relación que permite acceder a la información del usuario que escribió la reseña.

    product_id: int = Field(foreign_key="product.id")
    # `product_id`: Clave foránea que conecta la reseña con un producto específico.

    products: Product = Relationship(back_populates="reviews")
    # `products`: Una relación que permite acceder a la información del producto reseñado.