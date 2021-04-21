import 'package:flutter/material.dart';
import 'package:peercoin/models/server.dart';
import 'package:peercoin/providers/electrumconnection.dart';
import 'package:peercoin/providers/servers.dart';
import 'package:peercoin/tools/app_localizations.dart';
import 'package:peercoin/tools/app_routes.dart';
import 'package:provider/provider.dart';

class ServerSettingsScreen extends StatefulWidget {
  @override
  _ServerSettingsScreenState createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  bool _initial = true;
  String _walletName = "";
  List<Server> _servers = [];
  Map _indexCache = {};
  Servers _serversProvider;

  @override
  void didChangeDependencies() async {
    if (_initial) {
      _walletName = ModalRoute.of(context).settings.arguments;
      _serversProvider = Provider.of<Servers>(context);
      await loadServers();
      setState(() {
        _initial = false;
      });
    }

    super.didChangeDependencies();
  }

  Future<void> loadServers() async {
    final result = await _serversProvider.getServerDetailsList(_walletName);
    setState(() {
      _servers = result;
    });
  }

  Future<void> savePriorities(String serverUrl, int newIndex) async {
    if (newIndex != _indexCache[serverUrl]) {
      _indexCache[serverUrl] = newIndex;
      _servers[newIndex].setPriority = newIndex;
    }
  }

  Color calculateTileColor(int index, bool connectable) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color oddItemColor = colorScheme.primary.withOpacity(0.10);
    final Color evenItemColor = colorScheme.primary.withOpacity(0.3);

    if (!connectable) {
      return Theme.of(context).accentColor;
    } else if (index.isOdd) {
      return oddItemColor;
    }
    return evenItemColor;
  }

  @override
  void deactivate() {
    Provider.of<ElectrumConnection>(context).init(_walletName);
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            AppLocalizations.instance.translate('server_settings_title'),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: IconButton(
              onPressed: () async {
                var result = await Navigator.of(context)
                    .pushNamed(Routes.ServerAdd, arguments: _walletName);
                if (result == true) {
                  await loadServers();
                }
              },
              icon: Icon(Icons.add),
            ),
          )
        ],
      ),
      body: _servers.isEmpty
          ? Container()
          : ReorderableListView.builder(
              onReorder: (oldIndex, newIndex) {
                if (_servers[oldIndex].connectable == false) return;
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                setState(() {
                  final item = _servers.removeAt(oldIndex);
                  _servers.insert(newIndex, item);
                });
              },
              itemCount: _servers.length,
              itemBuilder: (ctx, index) {
                savePriorities(_servers[index].address, index);
                return Card(
                  key: Key('$index'),
                  child: ListTile(
                    leading: Icon(Icons.toc),
                    onLongPress: () {
                      if (_servers[index].userGenerated == true) {
                        showDialog(
                            context: context,
                            builder: (_) {
                              return AlertDialog(
                                title: Text(AppLocalizations.instance.translate(
                                    'server_settings_alert_generated_title')),
                                content: Text(_servers[index].address),
                                actions: <Widget>[
                                  TextButton.icon(
                                      label: Text(AppLocalizations.instance
                                          .translate(
                                              'server_settings_alert_cancel')),
                                      icon: Icon(Icons.cancel),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      }),
                                  TextButton.icon(
                                    label: Text(AppLocalizations.instance
                                        .translate('jail_dialog_button')),
                                    icon: Icon(Icons.check),
                                    onPressed: () {
                                      _serversProvider
                                          .removeServer(_servers[index]);
                                      //reload servers
                                      loadServers();
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                ],
                              );
                            });
                      } else {
                        showDialog(
                            context: context,
                            builder: (_) {
                              return AlertDialog(
                                title: Text(AppLocalizations.instance.translate(
                                    'server_settings_alert_hardcoded_title')),
                                content: Text(AppLocalizations.instance.translate(
                                    'server_settings_alert_hardcoded_content')),
                                actions: <Widget>[
                                  TextButton.icon(
                                    label: Text(
                                      AppLocalizations.instance
                                          .translate('jail_dialog_button'),
                                    ),
                                    icon: Icon(Icons.check),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                ],
                              );
                            });
                      }
                    },
                    trailing: IconButton(
                      onPressed: () {
                        final oldItem = _servers[index];
                        setState(() {
                          //toggle connectable
                          _servers[index].setConnectable =
                              !_servers[index].connectable;
                        });
                        //check if still one connectable server is left
                        if (_servers.firstWhere(
                                (element) => element.connectable == true,
                                orElse: () => null) ==
                            null) {
                          //show snack bar
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                              AppLocalizations.instance.translate(
                                  "server_settings_error_no_server_left"),
                              textAlign: TextAlign.center,
                            ),
                            duration: Duration(seconds: 2),
                          ));

                          //reset connectable
                          oldItem.setConnectable = true;
                        }
                        //connectable now false ? move to bottom of list
                        if (!_servers[index].connectable) {
                          final item = _servers.removeAt(index);
                          _servers.insert(_servers.length, item);
                          _servers[index].setPriority = _servers.length - 1;
                        } else {
                          final item = _servers.removeAt(index);
                          _servers.insert(0, item);
                          _servers[index].setPriority = 0;
                        }
                      },
                      icon: Icon(_servers[index].connectable
                          ? Icons.offline_bolt
                          : Icons.offline_bolt_outlined),
                    ),
                    tileColor:
                        calculateTileColor(index, _servers[index].connectable),
                    title: Text(_servers[index].address),
                  ),
                );
              }),
    );
  }
}

//TODO allow servers to be hidden