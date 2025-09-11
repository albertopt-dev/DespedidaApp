# 🏝️ DespedidaApp juego de pruebas con grupos de amigos, galería y chat para eventos de despedidas de solteros. (Flutter + Firebase)


**Despedida** es una app pensada para organizar la despedida de un amigo a modo de **juego por bases**. Los participantes crean un **circuito de pruebas** sobre un mapa tipo *“isla del tesoro”* y lo ejecutan en tiempo real. La app incluye **notificaciones** (con sonido especial para el novio al iniciar una prueba), **galería compartida** de fotos/vídeos y **chat del grupo** (sin el novio).

---

## Qué puedes hacer con la app

- **Crear un circuito** de bases (paradas) y **asignar pruebas** en cada una.
- **Elegir rol** al entrar: **amigos** o **novio**.
- **Sincronización en tiempo real**: todos ven el mismo circuito y progreso.
- **Iniciar pruebas**: cuando alguien comienza una, el **novio** recibe una **notificación muy sonora** con las instrucciones.
- **Grabar o hacer fotos** durante cada prueba y guardarlas en una **biblioteca común** del grupo.
- **Descargar** fotos o vídeos al terminar.
- **Chatear** entre los participantes (el novio no participa en el chat).

---

## Cómo funciona 

1. **Registro** y acceso al grupo del evento.
2. **Selección de rol**: amigos o novio.
3. **Configuración del circuito**: los amigos rellenan las pruebas (de un catálogo o personalizadas) en cada base del mapa.
4. **Iniciar juego**: todos ven el circuito completo; al empezar cada prueba, el **novio** recibe una **push** con sonido especial.
5. **Vivir la prueba**: grabar vídeos, sacar fotos, comentar en el chat y avanzar a la siguiente base.

---

## Roles

- **Novio**  
  - Recibe **notificaciones destacadas** al iniciar cada prueba.  
  - No participa en el **chat**.  
- **Amigos**  
  - Configuran el circuito, inician pruebas y suben contenido.  
  - Chatean y coordinan el evento.

---

## Tecnología

- **Frontend**: Flutter (Android, iOS y Web/PWA).  
- **Servicios**: Firebase (Auth, Firestore, Storage, Cloud Functions, FCM).  
- **Multimedia**: derivados **JPEG** web-safe para compatibilidad (especialmente en Safari iOS).  
- **Notificaciones**: FCM/APNs, **canales** en Android y **sonido personalizado** para el novio.

> Objetivo técnico: una experiencia **multiplataforma** con **tiempo real**, **multimedia compartida** y **notificaciones** fiables durante el evento.

---

## Estado del proyecto

- **Funcionalidad principal**: circuito de pruebas, roles, notificaciones al novio, galería compartida y chat del grupo.  
- **En desarrollo continuo**: mejoras de UX del mapa, optimización de descargas web y pequeños ajustes de PWA, ademas de expansiones futuras en cuanto a funcionalidades y experiencia.

---

## Capturas / Demo

- Pantalla principal 
<img width="429" height="873" alt="image" src="https://github.com/user-attachments/assets/fe838b37-d3ef-4b3b-9653-a59113417828" />


- Chat
<img width="429" height="874" alt="image" src="https://github.com/user-attachments/assets/f47566e3-f796-4406-a26d-2725d4f048d8" />


- Creacion de la prueba y sus funcionalidades
<img width="425" height="875" alt="image" src="https://github.com/user-attachments/assets/3a8f0648-e6f5-4e93-a32b-7a0eadf82bb8" />
<img width="430" height="883" alt="image" src="https://github.com/user-attachments/assets/cea2ec8b-395f-4ef0-a7e5-08d10faf914b" />

---

## Privacidad (resumen)

- Los datos del evento y el contenido multimedia se almacenan en **Firebase**.  
- Accesos y permisos están restringidos al **grupo** del evento.  
- No se comparten datos con terceros fuera del servicio.

---

## Próximos pasos

- Menu de opciones.  
- Perfil de usuario.  
- Configuración general de la app.
- Todo lo que se me vaya ocurriendo para hacerla mas entretenida aún

---

## Estado de publicación
- Google Play: ⏳ no publicada
- TestFlight (iOS): ⏳ no publicada
- PWA/Web demo: ⏳ no publicada

> Por ahora no hay builds públicas. Si necesitas evaluarla, puedo compartir un APK/TestFlight privado bajo petición.


## Contacto

Si quieres saber más sobre la implementación o ver el código de alguna parte concreta, puedes contactarme y te guío por los archivos clave.
