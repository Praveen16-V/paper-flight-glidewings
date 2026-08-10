import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Lightweight, hand-written localization layer for the first-run funnel.
///
/// Keeping the strings behind stable keys lets the rest of the game migrate in
/// small slices without waiting for a full copy pass. English is the fallback
/// for missing translations. Add a locale to [_localizedValues] and
/// [supportedLocales] to make it available to the app.
class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('en'));
  }

  String text(String key, [Map<String, Object> values = const {}]) {
    final language = _localizedValues.containsKey(locale.languageCode)
        ? locale.languageCode
        : 'en';
    var value = _localizedValues[language]?[key] ??
        _localizedValues['en']![key] ??
        key;
    for (final entry in values.entries) {
      value = value.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return value;
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app.title': 'Paper Flight',
      'menu.title': 'PAPER FLIGHT',
      'menu.best': 'BEST',
      'menu.play': 'PLAY',
      'menu.playClassic': 'PLAY CLASSIC',
      'menu.startZen': 'START ZEN',
      'menu.viewDaily': 'VIEW DAILY',
      'menu.chooseTrial': 'CHOOSE TRIAL',
      'menu.howToPlay': 'How to play',
      'menu.hangar': 'Hangar',
      'menu.shop': 'Shop',
      'menu.challenges': 'Challenges',
      'menu.settings': 'Settings',
      'menu.allModesHint': 'Tap for all modes',
      'mode.classic': 'Classic Flight',
      'mode.classicTagline': 'Endless arcade',
      'mode.zen': 'Zen Flight',
      'mode.zenTagline': 'No crashes. Just glide.',
      'mode.daily': 'Daily Seeded',
      'mode.dailyTagline': 'One run a day',
      'mode.trial': 'Precision Trial',
      'mode.trialTagline': 'Earn your stars',
      'mode.bestScore': 'Best: {score}',
      'mode.bestDistance': 'Best: {distance} m',
      'mode.notPlayed': 'Not played yet',
      'mode.notStarted': 'Not started',
      'mode.todaysRun': "Today's run",
      'mode.starsEarned': '★ {stars} earned',
      'guide.title': 'HOW TO PLAY',
      'guide.page': '{current} of {total}',
      'guide.skip': 'Skip',
      'guide.back': 'Back',
      'guide.next': 'Next',
      'guide.done': "Let's fly",
      'guide.close': 'Close guide',
      'guide.controlsTitle': 'Fly with one thumb',
      'guide.controlsBody':
          'Hold anywhere to climb. Release to settle into a glide. Steering follows the control style selected in Settings.',
      'guide.holdTitle': 'Hold / release',
      'guide.holdBody': 'Hold to rise • release to glide',
      'guide.steerTitle': 'Steer',
      'guide.steerTilt': 'Tilt your phone left or right. Each run calibrates to the way you are holding it.',
      'guide.steerJoystick': 'Touch and drag the floating stick left or right. It appears under your thumb.',
      'guide.steerZones': 'Press the left or right half of the screen to bank in that direction.',
      'guide.boostTitle': 'Emergency boost',
      'guide.boostBody': 'Tap BOOST or flick upward. Charges refill as you travel.',
      'guide.scoringTitle': 'Build a better flight',
      'guide.scoringBody': 'Distance is your base score. Risk and clean routes turn a safe glide into a high-scoring run.',
      'guide.distanceTitle': 'Travel farther',
      'guide.distanceBody': 'Every meter adds score and gradually raises the pace.',
      'guide.comboTitle': 'Follow coin lines',
      'guide.comboBody': 'Collect coins without a gap to grow the combo multiplier.',
      'guide.nearMissTitle': 'Thread the gaps',
      'guide.nearMissBody': 'Close shaves award bonus points. The tighter the pass, the larger the reward.',
      'guide.cleanTitle': 'Fly smoothly',
      'guide.cleanBody': 'Clean flight and thermal-surf streaks add escalating bonuses.',
      'guide.powerTitle': 'Read the power-ups',
      'guide.powerBody': 'Pickups activate immediately. Their icon and remaining time appear at the lower left of the HUD.',
      'guide.shield': 'Shield',
      'guide.shieldBody': 'Absorbs one collision',
      'guide.magnet': 'Magnet',
      'guide.magnetBody': 'Pulls nearby coins',
      'guide.ghost': 'Ghost',
      'guide.ghostBody': 'Pass through hazards',
      'guide.slowMo': 'Slow motion',
      'guide.slowMoBody': 'Creates more reaction time',
      'guide.coinRush': 'Coin rush',
      'guide.coinRushBody': 'Doubles coin value and adds showers',
      'guide.loopTitle': 'Choose your flight loop',
      'guide.loopBody': 'Each mode has a different goal and reward loop. Only Classic feeds the shared coin economy.',
      'guide.classicLoop': 'Fly → earn coins → unlock planes → finish challenges',
      'guide.zenLoop': 'Relaxed endless flight • no crashes • no banked rewards',
      'guide.dailyLoop': 'One fair attempt each UTC day • leaderboard score only',
      'guide.trialLoop': 'Handcrafted courses • complete objectives • earn up to 3 stars',
      'intro.eyebrow': 'FIRST-TIME MODE TIP',
      'intro.title': 'Before you fly',
      'intro.classicBody': 'Avoid hazards, follow coin lines, and push your distance. Coins bank after the run and challenge progress counts here.',
      'intro.zenBody': 'There are no crash deaths. Obstacles gently bounce you away. This mode is for relaxing and does not bank coins or challenge progress.',
      'intro.dailyBody': 'Everyone gets the same wind and layout. Your single attempt is consumed when you start, even if you quit. The reward is leaderboard rank only.',
      'intro.trialBody': 'Fly the course objective with precision. One collision ends the attempt; time, completion, and collected course coins determine your stars.',
      'intro.classicRule': 'Economy + challenges enabled',
      'intro.zenRule': 'No deaths • no economy rewards',
      'intro.dailyRule': 'One attempt • resets at 00:00 UTC',
      'intro.trialRule': 'One hit ends the course',
      'intro.control': 'Controls: {control}',
      'intro.controlTilt': 'hold to climb, release to glide, tilt to steer',
      'intro.controlJoystick': 'hold to climb, release to glide, drag to steer',
      'intro.controlZones': 'hold to climb, release to glide, tap left/right to steer',
      'intro.fullGuide': 'Open full guide',
      'intro.start': 'Start flight',
      'pause.howToPlay': 'How to play',
      'a11y.coins': '{amount} coins',
      'a11y.gems': '{amount} gems',
      'a11y.previousMode': 'Previous game mode',
      'a11y.nextMode': 'Next game mode',
      'a11y.openModes': 'Open all game modes',
    },
    'es': {
      'app.title': 'Vuelo de Papel',
      'menu.title': 'VUELO DE PAPEL',
      'menu.best': 'RÉCORD',
      'menu.play': 'JUGAR',
      'menu.playClassic': 'JUGAR CLÁSICO',
      'menu.startZen': 'INICIAR ZEN',
      'menu.viewDaily': 'VER VUELO DIARIO',
      'menu.chooseTrial': 'ELEGIR PRUEBA',
      'menu.howToPlay': 'Cómo jugar',
      'menu.hangar': 'Hangar',
      'menu.shop': 'Tienda',
      'menu.challenges': 'Retos',
      'menu.settings': 'Ajustes',
      'menu.allModesHint': 'Toca para ver todos los modos',
      'mode.classic': 'Vuelo clásico',
      'mode.classicTagline': 'Arcade infinito',
      'mode.zen': 'Vuelo zen',
      'mode.zenTagline': 'Sin choques. Solo vuela.',
      'mode.daily': 'Semilla diaria',
      'mode.dailyTagline': 'Un intento al día',
      'mode.trial': 'Prueba de precisión',
      'mode.trialTagline': 'Consigue estrellas',
      'mode.bestScore': 'Récord: {score}',
      'mode.bestDistance': 'Récord: {distance} m',
      'mode.notPlayed': 'Aún no jugado',
      'mode.notStarted': 'Sin empezar',
      'mode.todaysRun': 'Vuelo de hoy',
      'mode.starsEarned': '★ {stars} ganadas',
      'guide.title': 'CÓMO JUGAR',
      'guide.page': '{current} de {total}',
      'guide.skip': 'Omitir',
      'guide.back': 'Atrás',
      'guide.next': 'Siguiente',
      'guide.done': 'A volar',
      'guide.close': 'Cerrar guía',
      'guide.controlsTitle': 'Vuela con un pulgar',
      'guide.controlsBody': 'Mantén pulsado para subir y suelta para planear. La dirección usa el control elegido en Ajustes.',
      'guide.holdTitle': 'Mantén / suelta',
      'guide.holdBody': 'Mantén para subir • suelta para planear',
      'guide.steerTitle': 'Dirección',
      'guide.steerTilt': 'Inclina el teléfono a izquierda o derecha. Cada vuelo se calibra según cómo lo sostienes.',
      'guide.steerJoystick': 'Toca y arrastra el joystick flotante. Aparece debajo de tu pulgar.',
      'guide.steerZones': 'Pulsa la mitad izquierda o derecha de la pantalla para girar.',
      'guide.boostTitle': 'Impulso de emergencia',
      'guide.boostBody': 'Toca IMPULSO o desliza hacia arriba. Las cargas se recuperan al avanzar.',
      'guide.scoringTitle': 'Mejora cada vuelo',
      'guide.scoringBody': 'La distancia es la puntuación base. El riesgo y las rutas limpias aumentan el resultado.',
      'guide.distanceTitle': 'Llega más lejos',
      'guide.distanceBody': 'Cada metro suma puntos y aumenta poco a poco la velocidad.',
      'guide.comboTitle': 'Sigue las líneas de monedas',
      'guide.comboBody': 'Recoge monedas sin pausas para aumentar el multiplicador.',
      'guide.nearMissTitle': 'Pasa por los huecos',
      'guide.nearMissBody': 'Los roces cercanos dan puntos extra. Cuanto más cerca, mayor premio.',
      'guide.cleanTitle': 'Vuela con suavidad',
      'guide.cleanBody': 'Las rachas de vuelo limpio y térmicas dan bonos crecientes.',
      'guide.powerTitle': 'Conoce las mejoras',
      'guide.powerBody': 'Se activan al recogerlas. El icono y el tiempo restante aparecen abajo a la izquierda.',
      'guide.shield': 'Escudo',
      'guide.shieldBody': 'Absorbe un choque',
      'guide.magnet': 'Imán',
      'guide.magnetBody': 'Atrae monedas cercanas',
      'guide.ghost': 'Fantasma',
      'guide.ghostBody': 'Atraviesa obstáculos',
      'guide.slowMo': 'Cámara lenta',
      'guide.slowMoBody': 'Da más tiempo para reaccionar',
      'guide.coinRush': 'Lluvia de monedas',
      'guide.coinRushBody': 'Duplica su valor y añade más monedas',
      'guide.loopTitle': 'Elige tu forma de volar',
      'guide.loopBody': 'Cada modo tiene una meta y premios distintos. Solo Clásico usa la economía compartida.',
      'guide.classicLoop': 'Vuela → gana monedas → desbloquea aviones → completa retos',
      'guide.zenLoop': 'Vuelo relajado infinito • sin choques • sin premios guardados',
      'guide.dailyLoop': 'Un intento justo por día UTC • solo clasificación',
      'guide.trialLoop': 'Circuitos diseñados • cumple objetivos • gana hasta 3 estrellas',
      'intro.eyebrow': 'CONSEJO DEL MODO',
      'intro.title': 'Antes de volar',
      'intro.classicBody': 'Evita peligros, sigue monedas y aumenta tu distancia. Aquí guardas monedas y avanzas en los retos.',
      'intro.zenBody': 'No hay muertes por choque. Los obstáculos te apartan suavemente. No guarda monedas ni progreso de retos.',
      'intro.dailyBody': 'Todos reciben el mismo viento y recorrido. Tu único intento se consume al empezar, aunque abandones. Solo cuenta la clasificación.',
      'intro.trialBody': 'Cumple el objetivo con precisión. Un choque termina el intento; el tiempo, el objetivo y las monedas deciden tus estrellas.',
      'intro.classicRule': 'Economía y retos activados',
      'intro.zenRule': 'Sin muertes • sin premios económicos',
      'intro.dailyRule': 'Un intento • reinicio a las 00:00 UTC',
      'intro.trialRule': 'Un golpe termina el circuito',
      'intro.control': 'Controles: {control}',
      'intro.controlTilt': 'mantén para subir, suelta para planear e inclina para girar',
      'intro.controlJoystick': 'mantén para subir, suelta para planear y arrastra para girar',
      'intro.controlZones': 'mantén para subir, suelta para planear y toca izquierda/derecha',
      'intro.fullGuide': 'Abrir guía completa',
      'intro.start': 'Empezar vuelo',
      'pause.howToPlay': 'Cómo jugar',
      'a11y.coins': '{amount} monedas',
      'a11y.gems': '{amount} gemas',
      'a11y.previousMode': 'Modo de juego anterior',
      'a11y.nextMode': 'Modo de juego siguiente',
      'a11y.openModes': 'Abrir todos los modos de juego',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales
      .any((supported) => supported.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
