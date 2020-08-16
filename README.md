# Mongo-dart - MongoDB driver for Dart programming language

[![Pub](https://img.shields.io/pub/v/mongo_dart.svg)](https://pub.dartlang.org/packages/mongo_dart)
[![Build Status](https://travis-ci.org/mongo-dart/mongo_dart.svg?branch=master)](https://travis-ci.org/mongo-dart/mongo_dart)

Server-side driver library for MongoDb implemented in pure Dart.

## Basic usage

### Obtaining connection

```dart

  var db = Db("mongodb://localhost:27017/mongo_dart-blog");
  await db.open();
```

### Querying

Method `find` returns stream of maps and accept query parameters, usually build by fluent API query builder
provided by [mongo_dart_query](https://github.com/vadimtsushko/mongo_dart_query) as top level getter `where`

```dart

  var coll = db.collection('user');
  await coll.find(where.lt("age", 18)).toList();
  
  //....
  
  await coll
      .find(where.gt("my_field", 995).sortBy('my_field'))
      .forEach((v) => print(v));

  //....
  
  await coll.find(where.sortBy('itemId').skip(300).limit(25)).toList();
  
```

Method `findOne` take the same parameter and returns `Future` of just one map (mongo document)

```dart

  val = await coll.findOne(where.eq("my_field", 17).fields(['str_field','my_field']));
```

Take notice in these samples that unlike mongo shell such parameters as projection (`fields`), `limit` and `skip`
are passed as part of regular query through query builder

### Inserting documents

```dart

  await usersCollection.insertAll([
    {'login': 'jdoe', 'name': 'John Doe', 'email': 'john@doe.com'},
    {'login': 'lsmith', 'name': 'Lucy Smith', 'email': 'lucy@smith.com'}
  ]);
```

### Updating documents

You can update whole document with method `save`

```dart

  var v1 = await coll.findOne({"name": "c"});
  v1["value"] = 31;
  await coll.save(v1);
```

or you can perform field level updates with method `update` and top level getter `modify` for ModifierBuilder fluent API

```dart

  coll.update(where.eq('name', 'Daniel Robinson'), modify.set('age', 31));

```

### Removing documents

```dart

  students.remove(where.id(id));
  /// or, to remove all documents from collection
  students.remove();

```

Simple app on base of [JSON ZIPS dataset](http://media.mongodb.org/zips.json)

```dart
import 'package:mongo_dart/mongo_dart.dart';

void main() async {
  void displayZip(Map zip) {
    print(
        'state: ${zip["state"]}, city: ${zip["city"]}, zip: ${zip["id"]}, population: ${zip["pop"]}');
  }
  var db =
      Db("mongodb://reader:vHm459fU@ds037468.mongolab.com:37468/samlple");
  var zips = db.collection('zip');
  await db.open();
  print('''
******************** Zips for state NY, with population between 14000 and 16000,
******************** reverse ordered by population''');
  await zips
      .find(where
          .eq('state', 'NY')
          .inRange('pop', 14000, 16000)
          .sortBy('pop', descending: true))
      .forEach(displayZip);
  print('\n******************** Find ZIP for code 78829 (BATESVILLE)');
  var batesville = await zips.findOne(where.eq('id', '78829'));
  displayZip(batesville);
  print('******************** Find 10 ZIP closest to BATESVILLE');
  await zips
      .find(where.near('loc', batesville["loc"]).limit(10))
      .forEach(displayZip);
  print('closing db');
  await db.close();
}
```

### Building aggregation queries

```dart
import 'package: mongo_dart/mongo_dart.dart';

main() async {
  final db = Db('mongodb://127.0.0.1/testdb');
  final pipeline = AggregationPipelineBuilder()
    .addStage(
      Match(where.eq('status', 'A').map['\$query']))
    .addStage(
      Group(
        id: Field('cust_id'),
        fields: {
          'total': Sum(Field('amount'))
        }
      )).build();
  final result =
    await DbCollection(db, 'orders')
      .aggregateToStream(pipeline).toList();
  result.forEach(print);
}
```

### Secure connection

You can connect using a secured tls/ssl connection in one of this two ways:

* setting the secure connection parameter to true in db.open()

```dart
    await db.open(secure: true);
```

* adding a query parameter => "tls=true" (or "ssl=true").

```dart
    var db = DB('mongodb://www.example.com:27017/test?tls=true&authSource=admin');
              or
    var db = DB('mongodb://www.example.com:27017/test?ssl=true&authSource=admin');
```

No certificates can be used.

### Atlas (MongoDb cloud service) connection

Atlas requires a tls connection, so now it is possible to connect to this cloud service.
When creating a cluster Atlas shows you three ways of connecting:
Mongo shell, driver and MongoDb Compass Application.
The connection string is in Seedlist Connection Format (starts with mongodb+srv://).
At present this driver does not support this connection string format.
You can do the following:
connect with the mongo shell to the address given by the site, for example:

```bash
mongo "mongodb+srv://cluster0.xtest.mongodb.net/<database name>" --username <your Atlas user>
```

The shell will ask you the password, enter it.

immediately after, the shell will show you the connection string in Standard Connection Format (starting with "mongodb://") in a line starting with "connecting to", for example.

```code
connecting to: mongodb://cluster0-shard-00-00.xtest.mongodb.net:27017,cluster0-shard-00-02.xtest.mongodb.net:27017,cluster0-shard-00-01.xtest.mongodb.net:27017/<database name>?authSource=admin&compressors=disabled&gssapiServiceName=mongodb&replicaSet=atlas-stcn2i-shard-0&ssl=true
```

Copy that string and add your user and password immediately after the "mongodb://" schema in the format "username:password@", for example

```code
mongodb://<your user>:<your password>@cluster0-shard-00-00.xtest.mongodb.net:27017,cluster0-shard-00-02.xtest.mongodb.net:27017,cluster0-shard-00-01.xtest.mongodb.net:27017/<database name>?authSource=admin&compressors=disabled&gssapiServiceName=mongodb&replicaSet=atlas-stcn2i-shard-0&ssl=true
```

Here we are, you can use the latter Connection String in the Db constructor

```dart
var db = Db("mongodb://dbUser:password@cluster0-shard-00-00.xtest.mongodb.net:27017,cluster0-shard-00-02.xtest.mongodb.net:27017,cluster0-shard-00-01.xtest.mongodb.net:27017/test-db?authSource=admin&compressors=disabled&gssapiServiceName=mongodb&replicaSet=atlas-stcn2i-shard-0&ssl=true");
```

### See also

* [API Doc](http://www.dartdocs.org/documentation/mongo_dart/latest)

* [Feature check list](https://github.com/vadimtsushko/mongo_dart/blob/master/doc/feature_checklist.md)

* [Recent change notes](https://github.com/vadimtsushko/mongo_dart/blob/master/changelog.md)

* Additional [examples](https://github.com/vadimtsushko/mongo_dart/tree/master/example) and [tests](https://github.com/vadimtsushko/mongo_dart/tree/master/test)
