import 'dart:async';

import 'package:catan_iq/engine.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  startService();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Kons Catan IQ'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Timer timer;

  @override
  void dispose() {
    process.kill();
    super.dispose();
  }

  @override
  void initState() {
    timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) setState(() {});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (gameState == GameState.nothing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Waiting to join a lobby...'),
              SizedBox(height: 50),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: InteractiveViewer(
        scaleFactor: kDefaultMouseScrollToScaleFactor * 5,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < players.length + 1; i++)
                () {
                  Player player;
                  if (i == players.length) {
                    player = Player(
                      name: 'Bank',
                      amounts: {},
                    );

                    for (Resource r in Resource.values) {
                      player.amounts[r] = 19;
                    }

                    for (Player p in players) {
                      for (Resource r in Resource.values) {
                        player.amounts[r] = player.amounts[r]! - p.amounts[r]!;
                      }
                    }
                  } else {
                    player = players[i];
                  }
                  bool isYou = player.name == localName;

                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '${player.name}${isYou ? ' (You)' : ''}',
                          style: Theme.of(context).textTheme.titleLarge,
                          textScaleFactor: 1.3,
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (Resource r in Resource.values)
                              Column(
                                children: [
                                  SvgPicture.network(r.image, width: 50, height: 50),
                                  Text(
                                    '${player.amounts[r]}',
                                    style: Theme.of(context).textTheme.bodyLarge,
                                    textScaleFactor: 1.3,
                                  ),
                                ],
                              ),
                          ],
                        ),
                        if (i != players.length) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.network(ResourceImages.settlement, width: 50, height: 50),
                              Text(
                                'Settlements: ${player.remainingSettlements}',
                                style: Theme.of(context).textTheme.bodyLarge,
                                textScaleFactor: 1.3,
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.network(ResourceImages.city, width: 50, height: 50),
                              Text(
                                'Cities: ${player.remainingCities}',
                                style: Theme.of(context).textTheme.bodyLarge,
                                textScaleFactor: 1.3,
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.network(ResourceImages.road, width: 50, height: 50),
                              Text(
                                'Roads: ${player.remainingRoads}',
                                style: Theme.of(context).textTheme.bodyLarge,
                                textScaleFactor: 1.3,
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.network(ResourceImages.devCard, width: 50, height: 50),
                              Text(
                                'Development Cards: $devCards',
                                style: Theme.of(context).textTheme.bodyLarge,
                                textScaleFactor: 1.3,
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (DevelopmentCard card in DevelopmentCard.values)
                                Column(
                                  children: [
                                    SvgPicture.network(card.image, width: 50, height: 50),
                                    Text(
                                      '${DevelopmentCard.amounts[card]}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                      textScaleFactor: 1.3,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }(),
            ],
          ),
        ),
      ),
    );
  }
}

abstract class ResourceImages {
  static const String wood = "https://colonist.io/dist/images/card_lumber.svg";
  static const String sheep = "https://colonist.io/dist/images/card_wool.svg";
  static const String wheat = "https://colonist.io/dist/images/card_grain.svg";
  static const String brick = "https://colonist.io/dist/images/card_brick.svg";
  static const String stone = "https://colonist.io/dist/images/card_ore.svg";

  static const String settlement = "https://colonist.io/dist/images/settlement_gold.svg";
  static const String city = "https://colonist.io/dist/images/city_gold.svg";
  static const String road = "https://colonist.io/dist/images/road_gold.svg";

  static const String devCard = "https://colonist.io/dist/images/card_devcardback.svg";
  static const String robberCard = "https://colonist.io/dist/images/card_knight.svg";
  static const String monopolyCard = "https://colonist.io/dist/images/card_monopoly.svg";
  static const String roadBuildingCard = "https://colonist.io/dist/images/card_roadbuilding.svg";
  static const String yearOfPlentyCard = "https://colonist.io/dist/images/card_yearofplenty.svg";
  static const String victoryPointCard = "https://colonist.io/dist/images/card_vp.svg";
}

extension ImageExtension on Resource {
  String get image {
    switch (this) {
      case Resource.brick:
        return ResourceImages.brick;
      case Resource.sheep:
        return ResourceImages.sheep;
      case Resource.stone:
        return ResourceImages.stone;
      case Resource.wheat:
        return ResourceImages.wheat;
      case Resource.wood:
        return ResourceImages.wood;
    }
  }
}
