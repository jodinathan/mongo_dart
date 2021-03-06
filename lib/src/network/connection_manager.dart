part of mongo_dart;

class _ConnectionManager {
  final _log = Logger('ConnectionManager');
  final Db db;
  final _connectionPool = <String, _Connection>{};
  final replyCompleters = <int, Completer<MongoResponseMessage>>{};
  final sendQueue = Queue<MongoMessage>();
  _Connection _masterConnection;

  _ConnectionManager(this.db);

  _Connection get masterConnection => _masterConnection;

  _Connection get masterConnectionVerified {
    if (_masterConnection != null && !_masterConnection._closed) {
      return _masterConnection;
    } else {
      throw MongoDartError('No master connection');
    }
  }

  Future _connect(_Connection connection) async {
    await connection.connect();
    var isMasterCommand = DbCommand.createIsMasterCommand(db);
    var replyMessage = await connection.query(isMasterCommand);
    _log.fine(() => replyMessage.documents[0].toString());
    var master = replyMessage.documents[0]['ismaster'] == true;
    connection.isMaster = master;
    if (master) {
      _masterConnection = connection;
    }
    connection.serverCapabilities
        .getParamsFromIstMaster(replyMessage.documents[0]);

    if (db._authenticationScheme == null) {
      if (connection.serverCapabilities.maxWireVersion >= 3) {
        db._authenticationScheme = AuthenticationScheme.SCRAM_SHA_1;
      } else {
        db._authenticationScheme = AuthenticationScheme.MONGODB_CR;
      }
    }
    if (connection.serverConfig.userName == null) {
      _log.fine(() => '$db: ${connection.serverConfig.hostUrl} connected');
    } else {
      try {
        await db.authenticate(
            connection.serverConfig.userName, connection.serverConfig.password,
            connection: connection);
        _log.fine(() => '$db: ${connection.serverConfig.hostUrl} connected');
      } catch (e) {
        if (connection == _masterConnection) {
          _masterConnection = null;
        }
        await connection.close();
        rethrow;
      }
    }
    return true;
  }

  Future<void> open(WriteConcern writeConcern) async {
    var connectionErrors = [];
    for (var hostUrl in _connectionPool.keys) {
      var connection = _connectionPool[hostUrl];
      try {
        await _connect(connection);
      } catch (e) {
        connectionErrors.add(e);
      }
    }
    if (connectionErrors.isNotEmpty) {
      if (_masterConnection == null) {
        for (var error in connectionErrors) {
          _log.severe('$error');
        }
        // Simply returns the first exception to be more compatible
        // with previous error management.
        throw connectionErrors.first;
      } else {
        for (var error in connectionErrors) {
          _log.warning('$error');
        }
      }
    }
    db.state = State.OPEN;
    db.masterConnection.serverStatus
        .processServerStatus(await db.serverStatus());
  }

  Future close() async {
    while (sendQueue.isNotEmpty) {
      masterConnection._sendBuffer();
    }
    sendQueue.clear();

    _masterConnection == null;

    for (var hostUrl in _connectionPool.keys) {
      var connection = _connectionPool[hostUrl];
      _log.fine(() => '$db: ${connection.serverConfig.hostUrl} closed');
      await connection.close();
    }
    replyCompleters.clear();
  }

  void addConnection(ServerConfig serverConfig) {
    var connection = _Connection(this, serverConfig);
    _connectionPool[serverConfig.hostUrl] = connection;
  }

  _Connection removeConnection(_Connection connection) {
    connection.close();
    if (connection.isMaster) {
      _masterConnection = null;
    }
    return _connectionPool.remove(connection.serverConfig.hostUrl);
  }
}
