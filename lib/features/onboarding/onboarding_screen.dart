import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      emoji: '🌿',
      title: 'NEXA',
      subtitle: 'Intelligence Pastorale',
      description:
          'Transformez n\'importe quelle photo de pâturage en plan de gestion intelligent — même sans connexion internet.',
      color: NexaTheme.vertDeep,
      accentColor: NexaTheme.vert,
    ),
    _OnboardingPage(
      emoji: '📸',
      title: 'Une photo',
      subtitle: 'Un plan complet',
      description:
          'Prenez une photo de l\'herbe. Notre IA EfficientNet-B2 analyse la biomasse disponible pour votre troupeau en quelques secondes.',
      color: Color(0xFF0A1A2F),
      accentColor: Color(0xFF3B82F6),
    ),
    _OnboardingPage(
      emoji: '🗺️',
      title: 'Nomade ou',
      subtitle: 'Sédentaire',
      description:
          'Délimitez votre zone sur la carte GPS. NEXA calcule exactement combien de jours votre troupeau peut rester — et quand partir.',
      color: Color(0xFF1A0A00),
      accentColor: NexaTheme.or,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Pages
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _pages.length,
            itemBuilder: (_, i) => _OnboardingPageView(page: _pages[i]),
          ),

          // Indicateurs + bouton
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, NexaTheme.noir.withOpacity(0.9)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? _pages[_currentPage].accentColor
                              : NexaTheme.blanc.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bouton
                  NexaButton(
                    label: _currentPage == _pages.length - 1
                        ? 'Commencer →'
                        : 'Suivant',
                    color: _pages[_currentPage].accentColor,
                    onTap: () {
                      if (_currentPage == _pages.length - 1) {
                        context.go('/');
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                  ),

                  // Skip
                  if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: () => context.go('/'),
                      child: Text(
                        'Passer',
                        style: NexaTheme.bodyM
                            .copyWith(color: NexaTheme.blanc.withOpacity(0.4)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final String emoji;
  final String title;
  final String subtitle;
  final String description;
  final Color color;
  final Color accentColor;

  const _OnboardingPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
    required this.accentColor,
  });
}

class _OnboardingPageView extends StatelessWidget {
  final _OnboardingPage page;
  const _OnboardingPageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.3),
          radius: 1.2,
          colors: [page.color, NexaTheme.noir],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Emoji animé
              Text(page.emoji, style: const TextStyle(fontSize: 80))
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.elasticOut)
                  .fadeIn(duration: 400.ms),

              const SizedBox(height: 40),

              // Title
              Text(
                page.title,
                style: NexaTheme.displayXL.copyWith(color: page.accentColor),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .slideY(begin: 0.3, duration: 500.ms, delay: 200.ms)
                  .fadeIn(duration: 500.ms, delay: 200.ms),

              Text(
                page.subtitle,
                style: NexaTheme.displayL,
                textAlign: TextAlign.center,
              )
                  .animate()
                  .slideY(begin: 0.3, duration: 500.ms, delay: 300.ms)
                  .fadeIn(duration: 500.ms, delay: 300.ms),

              const SizedBox(height: 24),

              // Description
              Text(
                page.description,
                style: NexaTheme.bodyL.copyWith(
                  color: NexaTheme.blanc.withOpacity(0.65),
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .slideY(begin: 0.2, duration: 500.ms, delay: 400.ms)
                  .fadeIn(duration: 500.ms, delay: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
