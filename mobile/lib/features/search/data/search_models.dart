import '../../activity/data/activity_models.dart';
import '../../groups/data/models/group_models.dart';

enum SearchCategory {
  people('PEOPLE', 'Mọi người'),
  groups('GROUPS', 'Nhóm'),
  activities('ACTIVITIES', 'Hoạt động'),
  conversations('CONVERSATIONS', 'Trò chuyện');

  final String wireValue;
  final String label;
  const SearchCategory(this.wireValue, this.label);
}

class SearchPerson {
  final String id;
  final String? username;
  final String? displayName;
  final bool avatarAvailable;

  const SearchPerson({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarAvailable,
  });

  factory SearchPerson.fromJson(Map<String, dynamic> json) => SearchPerson(
    id: _requiredString(json, 'id'),
    username: json['username'] as String?,
    displayName: json['displayName'] as String?,
    avatarAvailable: json['avatarAvailable'] == true,
  );
}

class SearchGroup {
  final String id;
  final String name;
  final GroupStatus status;
  final bool avatarAvailable;

  const SearchGroup({
    required this.id,
    required this.name,
    required this.status,
    required this.avatarAvailable,
  });

  factory SearchGroup.fromJson(Map<String, dynamic> json) => SearchGroup(
    id: _requiredString(json, 'id'),
    name: _requiredString(json, 'name'),
    status: GroupStatus.fromWire(_requiredString(json, 'status')),
    avatarAvailable: json['avatarAvailable'] == true,
  );
}

class SearchActivity {
  final String id;
  final String groupId;
  final String title;
  final DateTime? startAt;
  final ActivityStatus status;
  final ActivityLocation? location;

  const SearchActivity({
    required this.id,
    required this.groupId,
    required this.title,
    required this.startAt,
    required this.status,
    required this.location,
  });

  factory SearchActivity.fromJson(Map<String, dynamic> json) => SearchActivity(
    id: _requiredString(json, 'id'),
    groupId: _requiredString(json, 'groupId'),
    title: _requiredString(json, 'title'),
    startAt: json['startAt'] is String
        ? DateTime.parse(json['startAt'] as String)
        : null,
    status: ActivityStatusWire.parse(_requiredString(json, 'status')),
    location: json['location'] is Map
        ? ActivityLocation.fromJson(
            Map<String, dynamic>.from(json['location'] as Map),
          )
        : null,
  );
}

class SearchConversation {
  final String id;
  final String kind;
  final String? groupId;
  final String title;
  final String matchedTextSnippet;
  final DateTime matchedAt;

  const SearchConversation({
    required this.id,
    required this.kind,
    required this.groupId,
    required this.title,
    required this.matchedTextSnippet,
    required this.matchedAt,
  });

  factory SearchConversation.fromJson(Map<String, dynamic> json) =>
      SearchConversation(
        id: _requiredString(json, 'id'),
        kind: _requiredString(json, 'kind'),
        groupId: json['groupId'] as String?,
        title: _requiredString(json, 'title'),
        matchedTextSnippet: _requiredString(json, 'matchedTextSnippet'),
        matchedAt: DateTime.parse(_requiredString(json, 'matchedAt')),
      );
}

class SearchSection<T> {
  final List<T> items;
  final bool hasMore;

  const SearchSection({required this.items, required this.hasMore});

  factory SearchSection.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) {
    final rawItems = json['items'];
    if (rawItems is! List) throw const FormatException('Expected search items');
    return SearchSection<T>(
      items: rawItems
          .map((item) {
            if (item is! Map) {
              throw const FormatException('Expected search result');
            }
            return parse(Map<String, dynamic>.from(item));
          })
          .toList(growable: false),
      hasMore: json['hasMore'] == true,
    );
  }
}

class SearchResponse {
  final String query;
  final SearchSection<SearchPerson>? people;
  final SearchSection<SearchGroup>? groups;
  final SearchSection<SearchActivity>? activities;
  final SearchSection<SearchConversation>? conversations;

  const SearchResponse({
    required this.query,
    this.people,
    this.groups,
    this.activities,
    this.conversations,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) => SearchResponse(
    query: _requiredString(json, 'query'),
    people: _section(json['people'], SearchPerson.fromJson),
    groups: _section(json['groups'], SearchGroup.fromJson),
    activities: _section(json['activities'], SearchActivity.fromJson),
    conversations: _section(json['conversations'], SearchConversation.fromJson),
  );

  SearchSection<dynamic>? section(SearchCategory? category) =>
      switch (category) {
        null => null,
        SearchCategory.people => people,
        SearchCategory.groups => groups,
        SearchCategory.activities => activities,
        SearchCategory.conversations => conversations,
      };

  SearchResponse withSection<T>(
    SearchCategory category,
    SearchSection<T> section,
  ) => switch (category) {
    SearchCategory.people => SearchResponse(
      query: query,
      people: section as SearchSection<SearchPerson>,
    ),
    SearchCategory.groups => SearchResponse(
      query: query,
      groups: section as SearchSection<SearchGroup>,
    ),
    SearchCategory.activities => SearchResponse(
      query: query,
      activities: section as SearchSection<SearchActivity>,
    ),
    SearchCategory.conversations => SearchResponse(
      query: query,
      conversations: section as SearchSection<SearchConversation>,
    ),
  };
}

SearchSection<T>? _section<T>(
  Object? value,
  T Function(Map<String, dynamic>) parse,
) => value is Map
    ? SearchSection<T>.fromJson(Map<String, dynamic>.from(value), parse)
    : null;

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('Expected $key');
  return value;
}
