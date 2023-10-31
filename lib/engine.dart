import 'dart:io';

import 'package:catan_iq/main.dart';
import 'package:html/dom.dart';
import 'package:webdriver/sync_io.dart';
import 'package:chaleno/chaleno.dart';

enum GameState {
  nothing,
  lobby,
  ingame,
}

enum DevelopmentCard {
  robber,
  victoryPoint,
  monopoly,
  roadBuilding,
  yearOfPlenty;

  static Map<DevelopmentCard, int> amounts = {
    DevelopmentCard.robber: 14,
    DevelopmentCard.victoryPoint: 5,
    DevelopmentCard.monopoly: 2,
    DevelopmentCard.roadBuilding: 2,
    DevelopmentCard.yearOfPlenty: 2,
  };
}

extension DevImageExtension on DevelopmentCard {
  String get image {
    switch (this) {
      case DevelopmentCard.robber:
        return ResourceImages.robberCard;
      case DevelopmentCard.victoryPoint:
        return ResourceImages.victoryPointCard;
      case DevelopmentCard.monopoly:
        return ResourceImages.monopolyCard;
      case DevelopmentCard.roadBuilding:
        return ResourceImages.roadBuildingCard;
      case DevelopmentCard.yearOfPlenty:
        return ResourceImages.yearOfPlentyCard;
    }
  }
}

List<Player> players = [];
GameState gameState = GameState.nothing;
late Process process;
String localName = "";
int devCards = 25;

void startService() async {
  // run windows console command: ./chromedrover.exe --port=4444 --url-base=wd/hub
  process = await Process.start('C:\\Users\\Konstanius\\AndroidStudioProjects\\catan_iq\\chromedriver.exe', ['--port=4444', '--url-base=wd/hub']);

  // start the webdriver
  WebDriver driver = createDriver(desired: Capabilities.chrome);
  driver.get('https://www.colonist.io/');

  while (true) {
    // DateTime initializationTime = DateTime.now();
    players.clear();
    gameState = GameState.nothing;
    while (true) {
      // loop that runs while the game is in lobby
      await Future.delayed(const Duration(milliseconds: 250));

      // stdout.write('\rWaiting to join a game lobby (${DateTime.now().difference(initializationTime).inSeconds} s elapsed)');

      String url = driver.currentUrl;
      // must end with #<4 chars>
      // check if # at end of url is followed by 4 chars
      if (url.contains('#')) {
        break;
      }
    }

    await Future.delayed(const Duration(seconds: 1));

    // DateTime lobbyStart = DateTime.now();
    gameState = GameState.lobby;

    while (true) {
      // loop that runs while the game is in lobby
      try {
        String html = driver.pageSource;
        Parser parser = Parser(html);

        // class of player list is "scene_room_player_list"
        List<Result> results = parser.getElementsByClassName("scene_room_player_list");

        Result result = results[0];
        String innerHtml = result.innerHTML!;

        Parser innerParser = Parser(innerHtml);
        List<Result> playerResults = innerParser.getElementsByClassName("room_player_username");

        List<String> playerNames = [];
        for (Result playerResult in playerResults) {
          String playerName = playerResult.text!.trim();
          if (playerNames.contains(playerName) || playerName.isEmpty || playerName == 'Player') continue;

          playerNames.add(playerName);
        }

        // stdout.write('\r${playerNames.length} players in lobby (${DateTime.now().difference(lobbyStart).inSeconds} s elapsed)');

        // class of game chat is "game_chat_text_div"
        List<Result> chatResults = parser.getElementsByClassName("game_chat_text_div");
        if (chatResults.isNotEmpty) {
          players.clear();
          // assemble players and break
          for (String playerName in playerNames) {
            players.add(Player.create(playerName));
          }
          break;
        }

        // class of local player is "header_profile_username"
        List<Result> localPlayerResults = parser.getElementsByClassName("header_profile_username");
        if (localPlayerResults.isNotEmpty) {
          localName = localPlayerResults[0].text!.trim();
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 250));
    }

    // track bank resources (dev cards, and 19 - all player resources)
    devCards = 25;

    print('Players:');
    for (Player player in players) {
      if (player.name == localName) {
        print('${player.name} (you)');
      } else {
        print(player.name);
      }
    }

    print('\nStarting game...');

    int lastChatLength = 0;

    gameState = GameState.ingame;
    DevelopmentCard.amounts = {
      DevelopmentCard.robber: 14,
      DevelopmentCard.victoryPoint: 5,
      DevelopmentCard.monopoly: 2,
      DevelopmentCard.roadBuilding: 2,
      DevelopmentCard.yearOfPlenty: 2,
    };

    while (true) {
      await Future.delayed(const Duration(milliseconds: 250));

      // loop that runs while the game is in progress
      try {
        Parser parser = Parser(driver.pageSource);
        // class of game chat box is "game_chat_text_div"
        Result chatBoxResult = parser.getElementsByClassName("game_chat_text_div")[0];
        Parser chatBoxParser = Parser(chatBoxResult.innerHTML!);

        // class of game chat message is "message-post"
        List<Result> chatResults = chatBoxParser.getElementsByClassName("message-post");
        if (chatResults.length == lastChatLength) {
          continue;
        }

        List<Result> newChatResults = chatResults.sublist(lastChatLength);
        lastChatLength = chatResults.length;

        for (Result r in newChatResults) {
          try {
            // in this element, there are 2 children, we get the 2nd one
            Parser innerParser = Parser(r.innerHTML!);
            // get the first span
            Result spanResult = innerParser.getElementsByTagName("span")![0];

            // get the text of the span
            String text = spanResult.text!.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ').replaceAll('you', localName);

            String? name1;
            String? name2;

            // populate the names
            List<String> split = text.split(' ');
            for (int i = 0; i < split.length; i++) {
              String s = split[i].toLowerCase();
              for (Player player in players) {
                if (player.name.toLowerCase() == s) {
                  if (name1 == null) {
                    name1 = s;
                  } else {
                    name2 = s;
                    break;
                  }
                }
              }
            }

            if (name1 == null) {
              // probably ignored
              continue;
            }

            Player player1 = players.firstWhere((element) => element.name.toLowerCase() == name1);
            Player? player2;
            if (name2 != null) {
              player2 = players.firstWhere((element) => element.name.toLowerCase() == name2);
            }

            List<Resource> resources1 = [];
            List<Resource> resources2 = [];

            String innerHtml = "<div>${r.innerHTML}</div>";

            Parser innerParser2 = Parser(innerHtml);
            // get all children
            List<Element> children = innerParser2.children!;

            NodeList nodes = children[0].children[1].children[0].children[1].nodes;

            int currentMode = 0;
            bool had = false;
            for (dynamic child in nodes) {
              try {
                if (child is Element && child.localName == 'img') {
                  // mode 0 = player 1
                  // mode 1 = player 2
                  if (currentMode == 0) {
                    resources1.add(Resource.fromString(child.attributes['alt']!));
                    had = true;
                  } else if (currentMode == 1) {
                    resources2.add(Resource.fromString(child.attributes['alt']!));
                    had = true;
                  }
                } else if (had && child is Text && child.text.trim().isNotEmpty) {
                  currentMode++;
                  had = false;
                }
              } catch (e, s) {
                if (e.toString().contains('Invalid resource')) {
                  continue;
                }

                print(e);
                print(s);
              }
            }

            print('$name1: $resources1');
            print('$name2: $resources2');

            bool unknown = false;

            // cases:
            if (text.contains('built a') || text.contains('placed a')) {
              Element? last;
              for (Element child in children[0].children[1].children[0].children[1].children) {
                if (child.localName == 'img') {
                  last = child;
                }
              }

              String alt = last!.attributes['alt']!;

              switch (alt) {
                /// Settlement
                case 'settlement':
                  player1.buildSettlement();
                  break;

                /// City
                case 'city':
                  player1.buildCity();
                  break;

                /// Road
                case 'road':
                  player1.buildRoad();
                  break;
                default:
                  print('Unknown action: $text');
              }
            }

            /// (player) bought
            else if (text.contains('bought')) {
              player1.buyDevelopmentCard();
              devCards--;
            }

            /// (player) traded (resources) for (resources) with (player)
            else if (text.contains('traded') && text.contains('for')) {
              for (Resource resource in resources1) {
                player1.removeResource(resource, 1);
              }

              for (Resource resource in resources2) {
                player1.addResource(resource, 1);
              }

              for (Resource resource in resources1) {
                player2!.addResource(resource, 1);
              }

              for (Resource resource in resources2) {
                player2!.removeResource(resource, 1);
              }
            }

            /// (player) gave bank (resources) and took (resources)
            else if (text.contains('gave bank')) {
              for (Resource resource in resources1) {
                player1.removeResource(resource, 1);
              }

              for (Resource resource in resources2) {
                player1.addResource(resource, 1);
              }
            }

            /// (player) got (resources)
            else if (text.contains('got')) {
              for (Resource resource in resources1) {
                player1.addResource(resource, 1);
              }
            }

            /// (player) stole (resources) from (player)
            else if (text.contains('stole from')) {
              for (Resource resource in resources1) {
                player1.addResource(resource, 1);
              }

              for (Resource resource in resources1) {
                player2!.removeResource(resource, 1);
              }
            }

            /// (player) received starting resources (resources)
            else if (text.contains('received starting resources')) {
              for (Resource resource in resources1) {
                player1.addResource(resource, 1);
              }
            } else if (text.contains('stole')) {
              if (!text.contains(RegExp(r'stole \d'))) {
                /// (player) stole (resources)
                for (Resource resource in resources1) {
                  player1.addResource(resource, 1);
                }

                for (Resource resource in resources1) {
                  player2!.removeResource(resource, 1);
                }
              } else {
                /// Monopoly (player) stole (resources) from (player)
                RegExp regex = RegExp(r'stole \d');
                String stole = regex.stringMatch(text)!;
                stole = stole.replaceAll('stole ', '');
                int amount = int.parse(stole);

                for (Resource resource in resources1) {
                  player1.addResource(resource, amount);
                }

                Resource type = resources1[0];
                for (Player player in players) {
                  if (player == player1) continue;
                  player.clearResource(type);
                }
              }
            }

            /// (player) took from bank (resources)
            else if (text.contains('took from bank')) {
              for (Resource resource in resources1) {
                player1.addResource(resource, 1);
              }
            }

            /// (player) used [Road Building]
            else if (text.contains('used')) {
              if (text.contains('road building')) {
                player1.freeRoads += 2;
              }

              // get the type of dev card
              DevelopmentCard? card;
              if (text.contains('monopoly')) {
                card = DevelopmentCard.monopoly;
              } else if (text.contains('road building')) {
                card = DevelopmentCard.roadBuilding;
              } else if (text.contains('year of plenty')) {
                card = DevelopmentCard.yearOfPlenty;
              } else if (text.contains('knight')) {
                card = DevelopmentCard.robber;
              }

              if (card != null) {
                DevelopmentCard.amounts[card] = DevelopmentCard.amounts[card]! - 1;
              }
            }

            /// (player) discarded (resources)
            else if (text.contains('discarded')) {
              for (Resource resource in resources1) {
                player1.removeResource(resource, 1);
              }
            }

            // unknown
            else {
              const Set<String> ignored = {
                "robber",
                "rolled",
              };

              if (ignored.contains(text)) {
                continue;
              }

              unknown = true;
            }

            if (unknown) {
              print('Unknown action: $text');
            }

            // print the bank
            int bankBrick = 19;
            int bankWheat = 19;
            int bankWood = 19;
            int bankStone = 19;
            int bankSheep = 19;

            for (Player player in players) {
              bankBrick -= player.getResource(Resource.brick);
              bankWheat -= player.getResource(Resource.wheat);
              bankWood -= player.getResource(Resource.wood);
              bankStone -= player.getResource(Resource.stone);
              bankSheep -= player.getResource(Resource.sheep);
            }

            print('Bank: Brick: $bankBrick, Wheat: $bankWheat, Wood: $bankWood, Stone: $bankStone, Sheep: $bankSheep (Dev Cards: $devCards)');
          } catch (e, s) {
            print(e);
            print(s);

            // probably ignored
          }
        }
      } catch (e, s) {
        if (e.toString().contains('Invalid resource')) {
          continue;
        }

        // cases:
        if (e.toString().contains('NoSuchWindowException')) {
          print('Ended CATAN_IQ');
          exit(0);
        }

        // browser url isnt ingame anymore, reset to beginning
        try {
          if (!driver.currentUrl.contains('#')) {
            print('Game ended, restarting CATAN_IQ...');
            break;
          }
        } catch (e) {
          if (e.toString().contains('NoSuchWindowException')) {
            print('Ended CATAN_IQ');
            exit(0);
          }

          print(e);
          print(s);
        }

        print(e);
        print(s);
      }
    }
  }
}

class Player {
  Map<Resource, int> amounts;
  String name;

  int remainingRoads = 15;
  int remainingSettlements = 5;
  int remainingCities = 4;

  int freeSettlements = 2;
  int freeRoads = 2;

  Player({required this.amounts, required this.name});

  factory Player.create(String name) {
    return Player(
      amounts: {
        Resource.brick: 0,
        Resource.wheat: 0,
        Resource.wood: 0,
        Resource.stone: 0,
        Resource.sheep: 0,
      },
      name: name,
    );
  }

  void addResource(Resource resource, int amount) {
    amounts[resource] = amounts[resource]! + amount;
  }

  void removeResource(Resource resource, int amount) {
    amounts[resource] = amounts[resource]! - amount;
  }

  void clearResource(Resource resource) {
    amounts[resource] = 0;
  }

  int getResource(Resource resource) {
    return amounts[resource]!;
  }

  void buildRoad() {
    remainingRoads--;
    if (freeRoads > 0) {
      freeRoads--;
      return;
    }

    removeResource(Resource.brick, 1);
    removeResource(Resource.wood, 1);
  }

  void buildSettlement() {
    remainingSettlements--;
    if (freeSettlements > 0) {
      freeSettlements--;
      return;
    }

    removeResource(Resource.brick, 1);
    removeResource(Resource.wood, 1);
    removeResource(Resource.wheat, 1);
    removeResource(Resource.sheep, 1);
  }

  void buildCity() {
    remainingCities--;
    remainingSettlements++;

    removeResource(Resource.wheat, 2);
    removeResource(Resource.stone, 3);
  }

  void buyDevelopmentCard() {
    removeResource(Resource.wheat, 1);
    removeResource(Resource.sheep, 1);
    removeResource(Resource.stone, 1);
  }
}

enum Resource {
  brick,
  wheat,
  wood,
  stone,
  sheep;

  factory Resource.fromString(String s) {
    s = s.toLowerCase();
    switch (s) {
      case 'brick':
        return Resource.brick;
      case 'grain':
        return Resource.wheat;
      case 'lumber':
        return Resource.wood;
      case 'ore':
        return Resource.stone;
      case 'wool':
        return Resource.sheep;
      default:
        throw Exception('Invalid resource: $s');
    }
  }

  String get name {
    switch (this) {
      case Resource.brick:
        return 'Brick';
      case Resource.wheat:
        return 'Wheat';
      case Resource.wood:
        return 'Wood';
      case Resource.stone:
        return 'Stone';
      case Resource.sheep:
        return 'Sheep';
    }
  }
}
