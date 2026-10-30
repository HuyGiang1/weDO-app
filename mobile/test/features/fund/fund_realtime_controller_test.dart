import 'package:flutter/material.dart';
import 'package:mobile/core/realtime/realtime_binding.dart';
import 'package:mobile/core/realtime/realtime_sync.dart';
import 'package:mobile/features/chat/data/chat_realtime_client.dart';
import 'package:mobile/features/chat/data/chat_realtime_event.dart';
import 'package:mobile/features/fund/presentation/fund_screens.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/fund/application/fund_controllers.dart';
import 'package:mobile/features/fund/data/fund_api.dart';
import 'package:mobile/features/fund/data/fund_models.dart';
import 'package:mobile/features/fund/data/fund_repository.dart';
FundDetail fund(String name) => FundDetail.fromJson({'fundId':'f','groupId':'g','name':name,'ledgerBalance':'100.00'});
const offline = ApiException(transportFailure: ApiTransportFailure.network);
class Repo extends FundRepository {
  Repo(): super(FundApi(Dio()));
  final calls = <String>[];
  Object? failure;
  Completer<List<FundCollectionSummary>>? collectionGate;
  int writes = 0;
  @override Future<FundDetail> createFund(String group,{String? name}) async {writes++;return current;}
  Completer<FundDetail>? pending;
  final collections = <String,Completer<FundCollectionDetail>>{};
  FundDetail current = fund('initial');
  @override Future<FundDetail> getGroupFund(String group) async {calls.add('fund');if (failure != null) throw failure!;return pending == null ? current : pending!.future;}
  @override Future<List<FundCollectionSummary>> listCollections(String id,{String? status}) async {calls.add('collections');return collectionGate==null ? [] : collectionGate!.future;}
  @override Future<List<FundExpenseItem>> listFundExpenses(String id) async {calls.add('expenses');return [];}
  @override Future<List<FundReimbursementItem>> listReimbursements(String id,{String? status}) async {calls.add('reimbursements');return [];}
  @override Future<List<FundTransactionItem>> listTransactions(String id,{String? type,String? direction}) async {calls.add('transactions');return [];}
  @override Future<FundCollectionDetail> getCollectionDetail(String id) => collections.putIfAbsent(id,Completer<FundCollectionDetail>.new).future;
}
class Client extends NoopChatRealtimeClient {
 final frames=StreamController<ChatRealtimeEvent>.broadcast();
 @override Stream<ChatRealtimeEvent> get events=>frames.stream;
 void pong()=>frames.add(const ChatRealtimeEvent(type:ChatRealtimeEventType.pong,rawType:'PONG'));
}
void main() {
 testWidgets('Fund scoped transient refresh retains UI and has bounded PONG recovery', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1000,1800));
  final r=Repo();final c=GroupFundController(r);final client=Client();final sync=RealtimeSync(client);
  await tester.pumpWidget(RealtimeHost(sync:sync,child:MaterialApp(home:GroupFundScreen(groupId:'g',groupName:'QA',repository:r,controller:c))));await tester.pumpAndSettle();
  r.failure=offline;
  sync.accept({'type':'DOMAIN_CHANGED','eventId':'fund','eventType':'FUND_CONTRIBUTION_CREATED','scope':'group:g','aggregateId':'g'});
  await tester.pump(const Duration(milliseconds:100));await tester.pumpAndSettle();expect(c.value.fund,isNotNull);expect(c.value.stale,isTrue);expect(find.textContaining('Dữ liệu chưa được cập nhật'),findsOneWidget);
  final before=r.calls.where((x)=>x=='fund').length;client.pong();await tester.pump();await tester.pump(const Duration(milliseconds:100));await tester.pumpAndSettle();expect(r.calls.where((x)=>x=='fund').length,before+1);
  client.pong();await tester.pump();await tester.pump(const Duration(milliseconds:100));expect(r.calls.where((x)=>x=='fund').length,before+1);
  r.failure=null;sync.accept({'type':'SCOPE_SUBSCRIBED','scope':'group:g'});await tester.pump(const Duration(milliseconds:100));await tester.pumpAndSettle();expect(c.value.stale,isFalse);expect(tester.takeException(),isNull);
  final healthy=r.calls.length;client.pong();await tester.pump();await tester.pump(const Duration(milliseconds:100));expect(r.calls.length,healthy);
  await tester.pumpWidget(const SizedBox());c.dispose();await tester.runAsync(sync.dispose);await client.frames.close();await tester.binding.setSurfaceSize(null);
 });
 testWidgets('Fund scope loss clears cache while old REST request is pending', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1000,1800));final r=Repo();final c=GroupFundController(r);final sync=RealtimeSync(const NoopChatRealtimeClient());
  await tester.pumpWidget(RealtimeHost(sync:sync,child:MaterialApp(home:GroupFundScreen(groupId:'g',groupName:'QA',repository:r,controller:c))));await tester.pumpAndSettle();
  final gate=Completer<FundDetail>();r.pending=gate;sync.accept({'type':'SCOPE_RESYNC','scope':'group:g'});await tester.pump(const Duration(milliseconds:100));
  sync.accept({'type':'SCOPE_REVOKED','scope':'group:g'});await tester.pump();expect(c.value.fund,isNull);r.failure=const ApiException(statusCode:403);gate.complete(fund('protected'));await tester.pumpAndSettle();expect(c.value.fund,isNull);expect(tester.takeException(),isNull);
  await tester.pumpWidget(const SizedBox());c.dispose();await tester.runAsync(sync.dispose);await tester.binding.setSurfaceSize(null);
 });

  test('transient realtime failure retains authoritative fund then resync recovers',() async {
    final r=Repo();final c=GroupFundController(r);addTearDown(c.dispose);await c.load('g');final before=c.value.fund;
    r.failure=offline;await c.resync('g');expect(c.value.fund,same(before));expect(c.value.failure,isNotNull);
    r.failure=null;r.current=fund('current');await c.resync('g');expect(c.value.fund!.name,'current');expect(c.value.failure,isNull);
  });
  test('expense hint avoids unrelated collection/reimbursement reads',() async {
    final r=Repo();final c=GroupFundController(r);addTearDown(c.dispose);await c.load('g');r.calls.clear();await c.resync('g',eventTypes:{'FUND_EXPENSE_CREATED'});expect(r.calls,['fund','expenses','transactions']);
  });
  test('late failed resync cannot overwrite newer success',() async {
    final r=Repo();final c=GroupFundController(r);addTearDown(c.dispose);await c.load('g');final gate=Completer<FundDetail>();r.pending=gate;final old=c.resync('g');r.pending=null;r.current=fund('new');await c.resync('g');gate.completeError(offline);await old;expect(c.value.fund!.name,'new');expect(c.value.failure,isNull);
  });
  test('disposed controller ignores pending response',() async {
    final r=Repo();final c=GroupFundController(r);await c.load('g');final gate=Completer<FundDetail>();r.pending=gate;final old=c.resync('g');c.dispose();gate.complete(fund('late'));await old;
  });
  test('403 clears protected financial cache',() async {
    final r=Repo();final c=GroupFundController(r);addTearDown(c.dispose);await c.load('g');r.failure=const ApiException(statusCode:403);await c.resync('g');expect(c.value.fund,isNull);expect(c.value.collections,isEmpty);
  });
  test('late collection selection cannot replace latest selected collection',() async {
    final r=Repo();final c=GroupFundController(r);addTearDown(c.dispose);await c.load('g');final old=c.loadCollectionDetail('old');final fresh=c.loadCollectionDetail('new');r.collections['new']!.complete(FundCollectionDetail.fromJson({'collectionId':'new','fundId':'f'}));await fresh;r.collections['old']!.complete(FundCollectionDetail.fromJson({'collectionId':'old','fundId':'f'}));await old;expect(c.value.activeCollectionDetail!.collectionId,'new');
  });
  test('revoked scope clears immediately and rejects late response',() async {
    final r=Repo();final c=GroupFundController(r);addTearDown(c.dispose);await c.load('g');final gate=Completer<FundDetail>();r.pending=gate;final pending=c.resync('g');c.revokeAccess();expect(c.value.fund,isNull);gate.complete(fund('protected'));await pending;expect(c.value.fund,isNull);expect(c.value.failure!.statusCode,403);
  });
  test('stale financial cache never executes mutation and clears only after read success',() async {
    final r=Repo();final c=GroupFundController(r);addTearDown(c.dispose);await c.load('g');r.failure=offline;await c.resync('g');expect(c.value.stale,isTrue);expect(await c.createFund('g'),isFalse);expect(r.writes,0);r.failure=null;await c.resync('g');expect(c.value.stale,isFalse);
  });
  test('collection late result after access loss cannot reinsert protected data',() async {
    final r=Repo();final c=GroupFundController(r);addTearDown(c.dispose);await c.load('g');final pending=c.loadCollectionDetail('late');c.revokeAccess();r.collections['late']!.complete(FundCollectionDetail.fromJson({'collectionId':'late'}));await pending;expect(c.value.activeCollectionDetail,isNull);expect(c.value.fund,isNull);
  });

  test('workspace response after mutation cannot restore cache revoked while loading',() async {
    final r=Repo();final c=GroupFundController(r);addTearDown(c.dispose);await c.load('g');r.collectionGate=Completer();final pending=c.createFund('g');await Future<void>.delayed(Duration.zero);c.revokeAccess();r.collectionGate!.complete([]);await pending;expect(c.value.fund,isNull);
  });

}
