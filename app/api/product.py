# Importaciones necesarias para la aplicación FastAPI.
# List se utiliza para indicar que una variable es una lista de un tipo específico.
from typing import List
# APIRouter, Depends, HTTPException, status, Query son componentes de FastAPI
# que nos ayudan a crear rutas, manejar dependencias, errores y parámetros de consulta.
from fastapi import APIRouter, Depends, HTTPException, status, Query
# AsyncSession es el tipo de sesión asíncrona que usaremos para interactuar con la base de datos.
from sqlmodel.ext.asyncio.session import AsyncSession

# Importamos nuestra función para obtener la sesión de la base de datos.
from app.db.session import get_session
# Importamos las funciones CRUD (Crear, Leer, Actualizar, Borrar) para el producto.
from app.crud import product
# Importamos los modelos de datos (schemas) que definen la estructura de los
# productos para la creación y la respuesta pública.
from app.schemas.schemas import ProductCreate, ProductPublic

# Creamos una instancia de APIRouter. Esto nos permite modularizar nuestras rutas.
# Todas las rutas definidas en este archivo se agruparán bajo un prefijo, si se especifica en el main.py
product_router = APIRouter()

# ---
## Rutas de la API para la gestión de productos

### Crear un nuevo producto
# @product_router.post("/"):Este es un decorador que le indica a la aplicación que debe manejar las solicitudes HTTP POST 
# en la ruta raíz (/) de product_router. Una solicitud POST se utiliza típicamente para crear un nuevo recurso en el servidor.
# status_code=status.HTTP_201_CREATED: Esto especifica que si la solicitud es exitosa, 
# el servidor debe devolver un código de estado HTTP de 201. 
# Este código, 201 Created (201 Creado), es la respuesta estándar para una solicitud que ha creado exitosamente un nuevo recurso.
@product_router.post("/", status_code=status.HTTP_201_CREATED, response_model=ProductPublic)
async def create_new_product(
    product_data: ProductCreate, 
    session: AsyncSession = Depends(get_session)
):
    """
    Crea un nuevo producto en la base de datos.
    
    Args:
        product_data (ProductCreate): Los datos del producto a crear, recibidos en el cuerpo de la solicitud.
        session (AsyncSession): La sesión de la base de datos inyectada por FastAPI.
        
    Returns:
        ProductPublic: El producto recién creado, con su ID asignado.
    """
    # Llamamos a la función asíncrona para crear el producto y retornamos el resultado.
    new_product = await product.create_product(product_data=product_data, session=session)
    return new_product

### Obtener una lista de todos los productos
##@product_router.get("/"): Indica que esta función manejará las solicitudes HTTP GET en la ruta raíz (/) del router de productos. 
# Un router (en este caso, product_router) se usa para agrupar endpoints relacionados, por ejemplo, todos los endpoints de productos.

#response_model=List[ProductPublic]: Esta es una característica clave de FastAPI para la validación de datos. 
# Le dice a la API que la función va a devolver una lista de objetos que cumplen con el modelo Pydantic llamado ProductPublic. 
@product_router.get("/", response_model=List[ProductPublic])
async def get_all_products_list(session: AsyncSession = Depends(get_session)):
    """
    Obtiene una lista de todos los productos disponibles en la base de datos.
    
    Args:
        session (AsyncSession): La sesión de la base de datos.
        
    Returns:
        List[ProductPublic]: Una lista de objetos de producto.
    """
    # Llamamos a la función para obtener todos los productos y retornamos la lista.
    products = await product.get_all_products(session=session)
    return products

### Obtener los detalles de un producto por su ID
##@product_router.get("/{product_id}"): Indica que esta función manejará las solicitudes HTTP GET indica que el ID del producto se pasará como parte de la URL 
# response_model=ProductPublic: Le dice a FastAPI que la respuesta de esta función debe ser un solo objeto que coincida con el modelo Pydantic ProductPublic.
@product_router.get("/{product_id}", response_model=ProductPublic)
async def get_product_details(product_id: int, session: AsyncSession = Depends(get_session)):
    """
    Obtiene los detalles de un producto específico por su ID.
    
    Args:
        product_id (int): El ID del producto a buscar, extraído del URL.
        session (AsyncSession): La sesión de la base de datos.
        
    Raises:
        HTTPException: Si el producto con el ID especificado no se encuentra,
                       se devuelve un error 404 Not Found.
                       
    Returns:
        ProductPublic: El objeto del producto encontrado.
    """
    # Buscamos el producto por su ID.
    product_item = await product.get_product_by_id(product_id=product_id, session=session)
    # Si el producto no existe, lanzamos una excepción HTTP.
    if not product_item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Product with ID {product_id} not available")   

    # Si se encuentra, lo retornamos.
    return product_item