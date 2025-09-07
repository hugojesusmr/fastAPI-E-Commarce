# Importaciones necesarias para la configuración de la base de datos asíncrona
from curses import echo 
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.ext.asyncio.session import AsyncSession
from sqlalchemy.orm import sessionmaker
from app.core.config import settings # Asume que 'settings' contiene la configuración de la aplicación,
                                     # incluyendo la URL de la base de datos.

# Configuración del motor de base de datos asíncrono
# `create_async_engine` inicializa un motor de base de datos que permite operaciones asíncronas.
# `settings.DATABASE_URL` proviene de un módulo de configuración y contiene la cadena de conexión
# para la base de datos (e.g., `postgresql+asyncpg://usuario:contraseña@host/nombre_bd`).
# `echo=True` hará que SQLAlchemy registre todas las sentencias SQL generadas en la consola,
# lo cual es útil para la depuración.
engine = create_async_engine(settings.DATABASE_URL, echo=True)

# Configuración de la fábrica de sesiones asíncronas
# `sessionmaker` es una fábrica para crear objetos `Session`.
# `engine`: El motor asíncrono creado anteriormente.
# `class_=AsyncSession`: Especifica que las sesiones creadas serán `AsyncSession`,
# permitiendo el uso de `await` con operaciones de base de datos.
# `expire_on_commit=False`: Esta configuración evita que los objetos caduquen (se actualicen)
# después de un commit, permitiendo que los objetos cargados antes de un commit permanezcan
# utilizables en la sesión sin necesidad de recarga.
AsyncSessionFactory = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

# Función de inyección de dependencias para obtener una sesión asíncrona
# Diseñada para proporcionar una sesión de base de datos asíncrona a otras partes de la aplicación
# (por ejemplo, manejadores de rutas de FastAPI).
async def get_session():
    # Adquiere una AsyncSession de la fábrica. El `async with` asegura que la sesión
    # se cierre correctamente incluso si ocurren errores.
    async with AsyncSessionFactory() as session:
        try:
            # `yield session`: Proporciona el objeto `session` al llamador.
            # El llamador ejecutará sus operaciones de base de datos usando esta `session`.
            yield session
            # Si las operaciones realizadas por el llamador son exitosas,
            # `await session.commit()` confirma la transacción, guardando los cambios.
            await session.commit()
        except Exception:
            # Si ocurre algún error durante las operaciones, `await session.rollback()`
            # revierte la transacción para mantener la integridad de los datos.
            await session.rollback()
        finally:
            # Este bloque siempre se ejecuta.
            # `await session.close()` asegura que la sesión de la base de datos se cierre,
            # liberando sus recursos.
            await session.close()
