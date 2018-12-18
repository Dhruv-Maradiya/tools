// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import 'dependency.dart';
import 'errors.dart';

part 'pubspec.g.dart';

@JsonSerializable(createToJson: false)
class Pubspec {
  // TODO: executables
  // TODO: publish_to

  final String name;

  @JsonKey(fromJson: _versionFromString)
  final Version version;

  final String description;
  final String homepage;

  /// If there is exactly 1 value in [authors], returns it.
  ///
  /// If there are 0 or more than 1, returns `null`.
  @Deprecated(
      'Here for completeness, but not recommended. Use `authors` instead.')
  String get author {
    if (authors.length == 1) {
      return authors.single;
    }
    return null;
  }

  final List<String> authors;
  final String documentation;

  @JsonKey(fromJson: _environmentMap)
  final Map<String, VersionConstraint> environment;

  @JsonKey(fromJson: parseDeps, nullable: false)
  final Map<String, Dependency> dependencies;

  @JsonKey(name: 'dev_dependencies', fromJson: parseDeps, nullable: false)
  final Map<String, Dependency> devDependencies;

  @JsonKey(name: 'dependency_overrides', fromJson: parseDeps, nullable: false)
  final Map<String, Dependency> dependencyOverrides;

  /// If [author] and [authors] are both provided, their values are combined
  /// with duplicates eliminated.
  Pubspec(
    this.name, {
    this.version,
    String author,
    List<String> authors,
    Map<String, VersionConstraint> environment,
    this.homepage,
    this.documentation,
    this.description,
    Map<String, Dependency> dependencies,
    Map<String, Dependency> devDependencies,
    Map<String, Dependency> dependencyOverrides,
  })  : authors = _normalizeAuthors(author, authors),
        environment = environment ?? const {},
        dependencies = dependencies ?? const {},
        devDependencies = devDependencies ?? const {},
        dependencyOverrides = dependencyOverrides ?? const {} {
    if (name == null || name.isEmpty) {
      throw ArgumentError.value(name, 'name', '"name" cannot be empty.');
    }
  }

  factory Pubspec.fromJson(Map json) => _$PubspecFromJson(json);

  factory Pubspec.parse(String yaml, {sourceUrl}) {
    final item = loadYaml(yaml, sourceUrl: sourceUrl);

    if (item == null) {
      throw ArgumentError.notNull('yaml');
    }

    if (item is! YamlMap) {
      if (item is YamlNode) {
        throw parsedYamlException('Does not represent a YAML map.', item);
      }

      throw ArgumentError.value(yaml, 'yaml', 'Does not represent a YAML map.');
    }

    try {
      return Pubspec.fromJson(item as YamlMap);
    } on CheckedFromJsonException catch (error, stack) {
      throw parsedYamlExceptionFromError(error, stack);
    }
  }

  static List<String> _normalizeAuthors(String author, List<String> authors) {
    final value = Set<String>();
    if (author != null) {
      value.add(author);
    }
    if (authors != null) {
      value.addAll(authors);
    }
    return value.toList();
  }
}

Version _versionFromString(String input) => Version.parse(input);

Map<String, VersionConstraint> _environmentMap(Map source) =>
    source.map((k, value) {
      final key = k as String;
      if (key == 'dart') {
        // github.com/dart-lang/pub/blob/d84173eeb03c3/lib/src/pubspec.dart#L342
        // 'dart' is not allowed as a key!
        throw InvalidKeyException(
            source, 'dart', 'Use "sdk" to for Dart SDK constraints.');
      }

      VersionConstraint constraint;
      if (value == null) {
        constraint = null;
      } else if (value is String) {
        try {
          constraint = VersionConstraint.parse(value);
        } on FormatException catch (e) {
          throw CheckedFromJsonException(source, key, 'Pubspec', e.message);
        }

        return MapEntry(key, constraint);
      } else {
        throw CheckedFromJsonException(
            source, key, 'VersionConstraint', '`$value` is not a String.');
      }

      return MapEntry(key, constraint);
    });