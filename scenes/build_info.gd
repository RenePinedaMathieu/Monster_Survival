extends RefCounted

## Versión de la build: el deploy (.github/workflows/deploy.yml) cambia
## "dev" por el commit corto antes de exportar. El menú lo muestra chico
## abajo a la izquierda para saber qué versión tiene cargada cada
## teléfono (el navegador a veces sigue con la anterior).
const COMMIT := "dev"
