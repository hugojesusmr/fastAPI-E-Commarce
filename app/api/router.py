from fastapi import APIRouter
from app.api.category import category_router
from app.api.product import product_router

api_router = APIRouter()

api_router.include_router(category_router, prefix="/categories", tags=["Categories"])
api_router.include_router(product_router, prefix="/products", tags=["Products"])

