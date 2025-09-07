from typing import List
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from models.models import Product
from schemas import ProductCreate


async def create_product(product_data: ProductCreate, session: AsyncSession) -> Product:
    """
    Crea un nuevo producto en la base de datos.
    
    Args:
        product_data: Los datos del producto a crear, validados por el esquema ProductCreate.
        session: La sesión asíncrona de la base de datos.
    
    Returns:
        El objeto Product recién creado y guardado en la base de datos.
    """
    # Valida los datos del producto usando el modelo Product.
    db_product = Product.model_validate(product_data)
    
    # Añade el nuevo objeto a la sesión.
    session.add(db_product)
    
    # Guarda los cambios en la base de datos de forma asíncrona.
    await session.commit()
    
    # Refresca el objeto para obtener su ID y cualquier otro valor generado por la base de datos.
    await session.refresh(db_product)
    
    return db_product

# ---

async def get_all_products(session: AsyncSession) -> List[Product]:
    """
    Obtiene todos los productos de la base de datos.

    Args:
        session: La sesión asíncrona de la base de datos.
    
    Returns:
        Una lista de todos los objetos Product.
    """
    # Crea una sentencia de selección para obtener todos los productos.
    stmt = select(Product)
    
    # Ejecuta la sentencia de forma asíncrona.
    result = await session.exec(stmt)

    # Retorna todos los resultados como una lista.
    return result.all()

# ---

async def get_product_by_id(product_id: int, session: AsyncSession) -> Product:
    """
    Obtiene un producto específico de la base de datos por su ID.

    Args:
        product_id: El ID del producto que se desea obtener.
        session: La sesión asíncrona de la base de datos.
    
    Returns:
        El objeto Product si se encuentra, o None si no existe.
    """
    # Crea una sentencia de selección para buscar un producto por su ID.
    stmt = select(Product).where(Product.id == product_id)
    
    # Ejecuta la sentencia de forma asíncrona.
    result = await session.exec(stmt)
    
    # Retorna el primer resultado si existe, de lo contrario, retorna None.
    return result.one_or_none()