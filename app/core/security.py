# Importa la clase CryptContext del módulo passlib.context
# CryptContext es la clase principal para gestionar los esquemas de hasheo de contraseñas.
from passlib.context import CryptContext

# Crea una instancia de CryptContext.
# 'schemes=["bcrypt"]' especifica que se usará el algoritmo Bcrypt para el hasheo de contraseñas,
# que es un algoritmo fuerte y recomendado.
# 'deprecated="auto"' gestiona automáticamente los esquemas de hasheo antiguos si se encuentran.
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def get_password_hash(password: str) -> str:
    """
    Hashea una contraseña en texto plano usando Bcrypt.

    Args:
        password (str): La contraseña en texto plano a hashear.

    Returns:
        str: La versión hasheada y segura de la contraseña.
    """
    # Llama al método .hash() del objeto CryptContext para hashear la contraseña.
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Verifica si una contraseña en texto plano coincide con una contraseña hasheada.

    Args:
        plain_password (str): La contraseña en texto plano ingresada por el usuario.
        hashed_password (str): La contraseña hasheada almacenada en la base de datos.

    Returns:
        bool: True si las contraseñas coinciden, False en caso contrario.
    """
    # Llama al método .verify() para comparar la contraseña en texto plano
    # con la versión hasheada. Esta operación es segura y evita la comparación directa.
    return pwd_context.verify(plain_password, hashed_password)