O concepto principal que guiará o deseño da música do xogo é a combinación da música de aventura dos primeiros xogos da saga Zelda (The Legend of Zelda, The Legend of Zelda e The Legend of Zelda: Ocarina of Time) composta principalmente por [Koji Kondo](https://es.wikipedia.org/wiki/Koji_Kondo), coa música tradicional galega.

A composición da música de aventuras pode seguir as liñas indicadas no seguinte vídeo:

https://www.youtube.com/watch?v=Rm8bH4zthGo

Como inspiración da tradición galega podemos usar as seguintes webs que recompilan obras, partituras e arquivos midi nesta liña:

- [https://folkotecagalega.gal](https://folkotecagalega.gal)
## Guía de audio e música
Para o deseño sonoro de accións reais utilizaremos sons realistas, principalmente a partir de gravacións 

Como este é un proxecto de código aberto, todas as gravacións que usemos feitas por outras persoas alleas ao equipo deberán ter unha licencia aberta compatible con que sexa un proxecto comercial (de dominio público ou creative commons comercial).

Idealmente, as gravacións deberán estar feitas en Galiza. Para iso, usaremos as seguintes librerías de sons:  

- [https://xscxxtxr.org/](https://xscxxtxr.org/)
- [https://freesound.org/search/?f=tag%3A%22galicia%22](https://freesound.org/search/?f=tag%3A%22galicia%22)
- [https://freesound.org/search/?f=tag%3A%22galiza%22](https://freesound.org/search/?f=tag%3A%22galiza%22)
- [https://lo-fields.blogspot.com/](https://lo-fields.blogspot.com/) de Marco Maril  
- [http://mapasonoro.consellodacultura.gal/](http://mapasonoro.consellodacultura.gal/)
- [https://archive.org/search?query=creator%3A%22Xo%C3%A1n-Xil+L%C3%B3pez%22](https://archive.org/search?query=creator%3A%22Xo%C3%A1n-Xil+L%C3%B3pez%22)
- [https://archive.org/search?query=creator%3A%22Berio+Molina%22](https://archive.org/search?query=creator%3A%22Berio+Molina%22)
- [https://archive.org/search?query=creator%3A%22Marco+Maril%22](https://archive.org/search?query=creator%3A%22Marco+Maril%22)
- [https://soundcloud.com/carlossuarez/sonourus_mood](https://soundcloud.com/carlossuarez/sonourus_mood)
- [https://soundcloud.com/carlossuarez/cripta-do-mosteiro-de](https://soundcloud.com/carlossuarez/cripta-do-mosteiro-de)
- [https://www.laescuchaatenta.com/ediciones.php](https://www.laescuchaatenta.com/ediciones.php)
- [https://www.miteco.gob.es/es/parques-nacionales-oapn/red-parques-nacionales/parques-nacionales/islas-atlanticas/visita-virtual/gaviotas-patiamarillas.html](https://www.miteco.gob.es/es/parques-nacionales-oapn/red-parques-nacionales/parques-nacionales/islas-atlanticas/visita-virtual/gaviotas-patiamarillas.html)

Tamén poderiamos tomar gravacións de preto da Galiza:

- https://mapasonoru.com/
  
Cando isto non poida ser posible, usaremos sons libres das seguintes librerías:

- [https://freesound.org/](https://freesound.org/)
## Guía de música
Como base para o deseño da música e dos sons de interacción non realistas (clicks, hovers, sons de éxito, fracaso, etc.) usaremos un sintetizador FM ([Frecuencia Modulada](https://es.wikipedia.org/wiki/S%C3%ADntesis_por_modulaci%C3%B3n_de_frecuencias)) xa que nos permite xogar con sonoridades complexas con claras referencias estéticas aos 80.

Concretamente, usaremos o VST gratuito de [Dexed](https://asb2m10.github.io/dexed/), que emula ao mítico teclado DX7 de Yamaha.

Intentaremos usar como instrumento principal o asubío, para emular unha camiñada polo campo. As melodías deberían, polo tanto, de ser “asubiables”, é dicir, sen grandes saltos entre notas.  
  
Este asubío podería usarse tamén para facer os sons de éxito e fracaso de operacións, como se o personaxe celebrase ou lamentase o resultado. Tamén poderiamos usar o asubío para emular a fala dos personaxes, como se comunicasen desa forma. 

Tamén usaremos os VSTs [Carmucha](https://lijasvirtualsampler.com/carmucha) e [Breogán](https://lijasvirtualsampler.com/breogan-vsti), emuladores de pandeireta e gaita respectivamente, desenvolvidos por Lijas, como forma de apoiar o software feito en Galiza.

Na música, usaremos tamén a librería de samples de pandeiretas de [Lindisfarne](https://lindisfarne.site/en/samplepack), co que poderemos crear un contraste interesante entre gravacións reais de instrumentos tradicionais con sons completamente sintetizados.

Usaremos unha melodía que represente ao personaxe principal pero que vaia evolucionando, tanto melódica como armonicamente así como a nivel de produción, coas etapas da súa vida. As primeiras etapas serán máis de descubrimento e aventura; as últimas, de descanso e sabedoría.

Infancia:
![[Florilexio - Infancia.mp3]]
Adolescencia:
![[Florilexio - Adolescencia.mp3]]
Mediana idade:
![[Florilexio - Mediana idade.mp3]]
Vellez:
![[Florilexio - Vellez.mp3]]
## Pipeline de assets

Para a composición da música usaremos [Ableton Live](https://www.ableton.com/es/live/) por ser unha ferramenta potente e moi completa. E, sobre todo, por ser o DAW ao que máis acostumadas estamos.

Para a creación e modificación de audio para o deseño sonoro usaremos a ferramenta [Reaper](https://www.reaper.fm/), xa que facilita a realización de tarefas repetitivas (elimiñar ruidos, cortar cachos, aplicar eqs a varias pistas, recompilar, etc.)

Como motor de audio dentro do xogo usaremos [FMOD](https://www.fmod.com/), que comparte moitas funcionalidades con Ableton Live e pode comunicarse con Godot sen moito problema.