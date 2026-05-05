import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tintaviva/pages/clubes_page.dart';
import 'package:tintaviva/pages/perfil_page.dart';
import 'package:tintaviva/pages/mi_biblio_page.dart';
import 'package:tintaviva/theme/app_styles.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _hasShownGuide =
      false; // Para evitar que se muestre múltiples veces en la misma sesión

  final List<Widget> _paginas = [
    const MiBibliotecaPage(),
    const ClubesPage(),
    const PerfilPage(),
  ];

  final GlobalKey _keyBiblioteca = GlobalKey();
  final GlobalKey _keyClubes = GlobalKey();
  final GlobalKey _keyPerfil = GlobalKey();

  @override
  void initState() {
    super.initState();
    // No hacemos nada aquí aún, esperamos al build para tener el contexto de ShowCaseWidget
  }

  Future<void> _markOnboardingAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
  }

  void _tryStartShowCase(BuildContext showCaseContext) {
    if (_hasShownGuide) return;

    // Verificamos SharedPreferences
    SharedPreferences.getInstance().then((prefs) {
      final hasSeen = prefs.getBool('hasSeenOnboarding') ?? false;

      if (!hasSeen && mounted) {
        setState(
          () => _hasShownGuide = true,
        ); // Marcamos como mostrado para esta sesión

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try {
              ShowCaseWidget.of(
                showCaseContext,
              ).startShowCase([_keyBiblioteca, _keyClubes, _keyPerfil]);
            } catch (e) {
              mostrarSnackBar(context, "Error iniciando showcase: $e", Colors.red);
            }
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (showCaseContext) {
        if (!_hasShownGuide) {
          _tryStartShowCase(showCaseContext);
        }

        return Scaffold(
          body: IndexedStack(index: _selectedIndex, children: _paginas),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            selectedItemColor: AppColors.naranja,
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            items: [
              BottomNavigationBarItem(
                icon: Showcase(
                  key: _keyBiblioteca,
                  title: '📚 Tu Biblioteca Personal',
                  description:
                      'Gestiona tus libros, marca tu progreso y añade notas personales.',
                  targetPadding: const EdgeInsets.all(20),
                  overlayOpacity: 0.75,
                  overlayColor: AppColors.morado.withValues(alpha: 0.9),
                  blurValue: 4,
                  tooltipBackgroundColor: Colors.white,
                  textColor: AppColors.morado,
                  titleTextStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.morado,
                  ),
                  descTextStyle: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  onTargetClick: () {
                    ShowCaseWidget.of(showCaseContext).next();
                  },
                  disposeOnTap: true,
                  child: const Icon(Icons.library_books, size: 28),
                ),
                label: 'Biblioteca',
              ),
              BottomNavigationBarItem(
                icon: Showcase(
                  key: _keyClubes,
                  title: '👥 Clubs de Lectura',
                  description:
                      'Únete a clubs, debate metas con amigos y comparte tu pasión.',
                  targetPadding: const EdgeInsets.all(20),
                  overlayOpacity: 0.75,
                  overlayColor: AppColors.morado.withValues(alpha: 0.9),
                  blurValue: 4,
                  tooltipBackgroundColor: Colors.white,
                  textColor: AppColors.morado,
                  titleTextStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.morado,
                  ),
                  descTextStyle: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  onTargetClick: () {
                    ShowCaseWidget.of(showCaseContext).next();
                  },
                  disposeOnTap: true,
                  child: const Icon(Icons.groups, size: 28),
                ),
                label: 'Clubes',
              ),
              BottomNavigationBarItem(
                icon: Showcase(
                  key: _keyPerfil,
                  title: '👤 Tu Perfil de Lector',
                  description:
                      'Descubre tus estadísticas y configura tu cuenta.',
                  targetPadding: const EdgeInsets.all(20),
                  overlayOpacity: 0.75,
                  overlayColor: AppColors.morado.withValues(alpha: 0.9),
                  blurValue: 4,
                  tooltipBackgroundColor: Colors.white,
                  textColor: AppColors.morado,
                  titleTextStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.morado,
                  ),
                  descTextStyle: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  onTargetClick: () {
                    _markOnboardingAsSeen();
                    ShowCaseWidget.of(showCaseContext).dismiss();
                  },
                  disposeOnTap: true,
                  child: const Icon(Icons.person, size: 28),
                ),
                label: 'Perfil',
              ),
            ],
          ),
        );
      },
    );
  }
}
