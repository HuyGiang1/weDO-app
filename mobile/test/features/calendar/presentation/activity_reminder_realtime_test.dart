import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/realtime/realtime_binding.dart';
import 'package:mobile/core/realtime/realtime_sync.dart';
import 'package:mobile/features/chat/data/chat_realtime_client.dart';
import 'package:mobile/features/calendar/data/calendar_api.dart';
import 'package:mobile/features/calendar/data/calendar_models.dart';
import 'package:mobile/features/calendar/data/calendar_repository.dart';
import 'package:mobile/features/calendar/presentation/activity_reminder_panel.dart';
ActivityReminder value(bool allowed,{bool enabled=false,int offset=15}) => ActivityReminder(activityId:'a',configured:enabled,enabled:enabled,canConfigure:allowed,offsetMinutes:offset,unavailableReason:allowed?null:'ACTIVITY_UNSCHEDULED',remindAt:enabled?DateTime.utc(2026,10,30,12):null);
class Repo extends CalendarRepository {
 Repo():super(CalendarApi(Dio()));
 ActivityReminder current=value(false);
 Object? failure;
 Completer<ActivityReminder>? gate,write;
 int reads=0,writes=0;
 int? savedOffset;
 @override Future<ActivityReminder> getReminder(String id) async {reads++;if(failure!=null)throw failure!;return gate==null?current:gate!.future;}
 @override Future<ActivityReminder> updateReminder(String id,{required bool enabled,int? offsetMinutes}) async {writes++;savedOffset=offsetMinutes;return write==null?current=value(true,enabled:enabled,offset:offsetMinutes??15):write!.future;}
}
void main(){
 late Repo repo;late RealtimeSync sync;
 Future<void> mount(WidgetTester t,{bool allowed=false}) async {
  repo=Repo()..current=value(allowed);sync=RealtimeSync(const NoopChatRealtimeClient());
  await t.pumpWidget(RealtimeHost(sync:sync,child:MaterialApp(home:Scaffold(body:ActivityReminderPanel(activityId:'a',repository:repo)))));await t.pumpAndSettle();
  addTearDown(() async {await t.pumpWidget(const SizedBox());await t.runAsync(sync.dispose);});
 }
 Future<void> change(WidgetTester t,{String type='ACTIVITY_UPDATED',String id='event'}) async {
  sync.accept({'type':'DOMAIN_CHANGED','eventId':id,'eventType':type,'scope':'activity:a','aggregateId':'a'});await t.pump(const Duration(milliseconds:100));await t.pumpAndSettle();
 }
 testWidgets('scheduled invalidation refreshes reminder capability without remount',(t) async {
  await mount(t);final state=t.state(find.byType(ActivityReminderPanel));expect(find.text('Thêm ngày giờ trước khi đặt nhắc nhở.'),findsOneWidget);repo.current=value(true);await change(t);expect(t.state(find.byType(ActivityReminderPanel)),same(state));expect(find.text('Thêm ngày giờ trước khi đặt nhắc nhở.'),findsNothing);expect(t.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,isNotNull);
 });
 testWidgets('transient refresh preserves reminder; reconnect recovers; unrelated Task ignored',(t) async {
  await mount(t,allowed:true);final initial=repo.reads;await change(t,type:'TASK_STATUS_CHANGED');expect(repo.reads,initial);repo.failure=const ApiException(transportFailure:ApiTransportFailure.network);await change(t,id:'offline');expect(find.byType(SwitchListTile),findsOneWidget);expect(t.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,isNull);expect(t.takeException(),isNull);repo.failure=null;sync.accept({'type':'SCOPE_SUBSCRIBED','scope':'activity:a'});await t.pump(const Duration(milliseconds:100));await t.pumpAndSettle();expect(t.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,isNotNull);
 });
 testWidgets('scope revocation clears private state and ignores old request',(t) async {
  await mount(t,allowed:true);final gate=Completer<ActivityReminder>();repo.gate=gate;sync.accept({'type':'SCOPE_RESYNC','scope':'activity:a'});await t.pump(const Duration(milliseconds:100));repo.failure=const ApiException(statusCode:403);sync.accept({'type':'SCOPE_REVOKED','scope':'activity:a'});await t.pump();expect(find.byType(SwitchListTile),findsNothing);gate.complete(value(true,enabled:true));await t.pumpAndSettle();expect(find.byType(SwitchListTile),findsNothing);expect(t.takeException(),isNull);
 });
 testWidgets('pending read after disposal is ignored',(t) async {
  await mount(t,allowed:true);final gate=Completer<ActivityReminder>();repo.gate=gate;sync.accept({'type':'SCOPE_RESYNC','scope':'activity:a'});await t.pump(const Duration(milliseconds:100));await t.pumpWidget(const SizedBox());gate.complete(value(true));await t.pumpAndSettle();expect(t.takeException(),isNull);
 });
 testWidgets('unsaved offset survives realtime refresh and saves once',(t) async {
  await mount(t,allowed:true);await t.tap(find.byType(DropdownButton<int>));await t.pumpAndSettle();await t.tap(find.text('30 phút').last);await t.pumpAndSettle();await change(t);expect(t.widget<DropdownButton<int>>(find.byType(DropdownButton<int>)).value,30);await t.tap(find.byType(SwitchListTile));await t.pumpAndSettle();expect(repo.savedOffset,30);expect(repo.writes,1);
 });
 testWidgets('save response after revocation cannot restore denied state',(t) async {
  await mount(t,allowed:true);repo.write=Completer<ActivityReminder>();await t.tap(find.byType(SwitchListTile));await t.pump();repo.failure=const ApiException(statusCode:403);sync.accept({'type':'SCOPE_REVOKED','scope':'activity:a'});await t.pump();repo.write!.complete(value(true,enabled:true));await t.pumpAndSettle();expect(find.byType(SwitchListTile),findsNothing);expect(t.takeException(),isNull);
 });
}
