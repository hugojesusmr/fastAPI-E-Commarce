from fastapi import APIRouter
from app.routers.incidence_router import upload_router
from app.routers.product_router import product_router

api_router = APIRouter()

api_router.include_router(upload_router, prefix="/files", tags=["Files"])
api_router.include_router(product_router, prefix="/products", tags=["Products"])

