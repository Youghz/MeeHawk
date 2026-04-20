import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/ball_icon.dart';
import 'match_setup_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: MH.paper,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: MH.ballSoft,
                      shape: BoxShape.circle,
                      border: Border.all(color: MH.ball, width: 2),
                    ),
                    child: const Center(child: BallIcon(size: 44)),
                  ),
                  const SizedBox(height: 20),
                  Text('MeeHawk',
                      style: MH.sans(
                        size: 40,
                        weight: FontWeight.w800,
                        color: MH.ink,
                        letterSpacing: -0.5,
                      )),
                  const SizedBox(height: 4),
                  Text('Beach volley — scoring live',
                      style: MH.sans(
                        size: 14,
                        color: MH.pencil,
                        letterSpacing: 0.4,
                      )),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: 280,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const MatchSetupScreen(),
                        ));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MH.ink,
                        foregroundColor: MH.paper,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add, size: 20, color: MH.paper),
                          const SizedBox(width: 8),
                          Text('Nouveau match',
                              style: MH.sans(
                                size: 16,
                                weight: FontWeight.w600,
                                color: MH.paper,
                              )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
