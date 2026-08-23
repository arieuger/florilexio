# Inventario v1: rejilla, imágenes y cantidades

## Resumen

Completar la rejilla existente de 18 huecos para mostrar los tipos recogidos en orden de recogida, con su imagen y cantidad. Las plantas reutilizarán como imagen predeterminada la textura canónica de su escena, permitiendo una imagen específica opcional; los objetos deberán declarar siempre una imagen propia.

## Cambios principales

- Añadir a `ItemData` un método `get_inventory_icon()`.
  - En objetos devuelve `icon`, que será obligatorio.
  - En `PlantData` devuelve `icon` cuando esté definido y, en caso contrario, `sprite`.
- Convertir `PlantData.sprite` en la textura canónica de la planta:
  - Asignarla en todos los recursos de plantas existentes.
  - Hacer que `CollectablePlant` aplique esa textura al `Sprite2D` de la escena.
  - Conservar `ItemData.icon` como sobrescritura exclusiva para el inventario.
- Validar que toda planta tenga `sprite` y que todo objeto tenga `icon`. La botella de plástico necesitará un recurso gráfico concreto antes de poder mostrarse correctamente.
- Ampliar `InventorySlot` con `item_id`, icono y etiqueta de cantidad; ocultar la cantidad y limpiar todos los datos cuando el hueco esté vacío.
- Implementar `InventoryPanel.refresh()`:
  - Recorrer `InventoryManager.get_items()` respetando el orden de inserción.
  - Rellenar los primeros 18 huecos y limpiar los restantes.
  - Resolver cada imagen mediante `get_inventory_icon()`.
  - Refrescar al abrir el cuaderno y al recibir `inventory_changed`.
  - Ignorar temporalmente los tipos posteriores al 18 y emitir un aviso de depuración.
- Eliminar por ahora el código incompleto de hover/selección o dejar sus señales sin comportamiento, preparadas para la siguiente fase.

## Interfaces y comportamiento

- Nuevo método público: `ItemData.get_inventory_icon() -> Texture2D`.
- `icon` significa imagen específica del inventario; en plantas es opcional y en objetos obligatoria.
- `sprite` significa representación canónica de una planta tanto en el mundo como, por defecto, en el inventario.
- Si un tipo llega a cero y posteriormente vuelve a recogerse, reaparece al final del orden de recogida.
- No se incluyen todavía paginación, detalles, hover, descarte ni gestión del ramo.

## Pruebas

- Planta sin `icon`: utiliza exactamente su `sprite`.
- Planta con `icon`: utiliza la sobrescritura únicamente en el inventario.
- Objeto con imagen: muestra su icono concreto; objeto sin imagen produce error de validación.
- Añadir varias unidades actualiza la cantidad sin duplicar huecos.
- Eliminar un tipo limpia su hueco y compacta la rejilla.
- Inventario vacío deja los 18 huecos limpios.
- Con más de 18 tipos solo aparecen los primeros 18 y se genera el aviso esperado.
- Abrir, cerrar y cambiar de sección mantiene la rejilla sincronizada.
- Ejecutar la comprobación headless de Godot para detectar recursos, scripts o tipos inválidos.

## Supuestos

- La textura visible normal del `Sprite2D` representa la imagen canónica de cada planta; no se necesita renderizar la escena completa.
- La imagen definitiva de la botella de plástico será aportada como asset, ya que actualmente no existe una adecuada en el repositorio.
- La limitación de 18 tipos visibles es aceptada para esta primera versión.
