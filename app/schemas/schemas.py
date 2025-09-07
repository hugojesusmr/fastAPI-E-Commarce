from typing import List, Optional
from sqlmodel import SQLModel

# --- Modelos de Categoría ---

class CategoryBase(SQLModel):
    """
    Clase base para la categoría. Define los atributos comunes de una categoría.
    Hereda de SQLModel para ser compatible con la validación de datos (Pydantic) y ORM.
    """
    name: str

class CategoryCreate(CategoryBase):
    """
    Esquema para crear una nueva categoría.
    Hereda de CategoryBase ya que solo necesita el nombre para la creación.
    """
    pass

class CategoryPublic(CategoryBase):
    """
    Esquema para la representación pública de una categoría.
    Incluye el 'id' para su uso en respuestas de la API.
    """
    id: int
    
# --- Modelos de Usuario ---

class UserBase(SQLModel):
    """
    Clase base para el usuario.
    Actualmente no tiene atributos, pero se define para futuras extensiones.
    """
    pass

# --- Modelos de Reseña (Review) ---

class ReviewBase(SQLModel):
    """
    Clase base para la reseña. Define los atributos comunes de una reseña.
    """
    text: str
    rating: int

class ReviewCreate(ReviewBase):
    """
    Esquema para crear una nueva reseña.
    Requiere el 'product_id' para asociar la reseña a un producto.
    """
    product_id: int

class ReviewPublic(ReviewBase):
    """
    Esquema para la representación pública de una reseña.
    Incluye el 'id' para su uso en respuestas de la API.
    """
    id: int

# --- Modelos de Producto ---

class ProductBase(SQLModel):
    """
    Clase base para el producto. Define los atributos comunes de un producto.
    """
    name: str
    description: str
    price: float

class ProductCreate(ProductBase):
    """
    Esquema para crear un nuevo producto.
    Requiere el 'category_id' para asociar el producto a una categoría existente.
    """
    category_id: int

class ProductPublic(ProductBase):
    """
    Esquema para la representación pública de un producto.
    Incluye el 'id' y las relaciones con otras tablas.
    
    Atributos:
        id: El ID único del producto.
        category: Un objeto 'CategoryPublic' que representa la categoría del producto.
        reviews: Una lista de objetos 'ReviewPublic' que representan las reseñas del producto.
    """
    id: int
    category: CategoryPublic
    reviews: List[ReviewPublic] = []