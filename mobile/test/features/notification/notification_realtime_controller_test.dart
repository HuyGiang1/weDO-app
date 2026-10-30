import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/notification/data/notification_failure.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/notification/application/notification_controllers.dart';
import 'package:mobile/features/notification/data/notification_api.dart';
import 'package:mobile/features/notification/data/notification_models.dart';
import 'package:mobile/features/notification/data/notification_repository.dart';
NotificationItemModel item(String id,{bool read=false}) => NotificationItemModel.fromJson({'notificationId':id,'title':id,'isRead':read});
class Repo extends NotificationRepository {
 Repo():super(NotificationApi(Dio()));
 List<NotificationItemModel> items=[item('old')];
 Object? failure;
 Completer<MarkNotificationReadResult>? read;
 Completer<int>? all,badge;
 Completer<NotificationInboxPageModel>? inbox;
 @override Future<NotificationInboxPageModel> getInbox({int page=0,int size=30}) async { if (failure != null) throw failure!; return inbox == null ? NotificationInboxPageModel(items:List.of(items),page:page,size:size,totalElements:items.length,totalPages:1,hasNext:false) : inbox!.future; }
 @override Future<int> getUnreadCount() async => badge==null ? items.where((x)=>!x.isRead).length : badge!.future;
 @override Future<MarkNotificationReadResult> markRead(String id) => read!.future;
 @override Future<int> markAllRead() => all!.future;
}
void main(){
 test('markRead does not erase notification arriving while mutation is pending',() async {
  final r=Repo();final c=NotificationCenterController(r);addTearDown(c.dispose);await c.loadInbox();r.read=Completer();final pending=c.markRead('old');r.items=[item('new'),item('old',read:true)];await c.loadInbox(silent:true);r.read!.complete(MarkNotificationReadResult(notificationId:'old',isRead:true));await pending;expect(c.value.inbox!.items.map((x)=>x.notificationId),['new','old']);expect(c.value.unreadCount,1);
 });
 test('markAllRead does not mark notification created after commit as read',() async {
  final r=Repo();final c=NotificationCenterController(r);addTearDown(c.dispose);await c.loadInbox();r.all=Completer();final pending=c.markAllRead();r.items=[item('new'),item('old',read:true)];await c.loadInbox(silent:true);r.all!.complete(1);await pending;expect(c.value.inbox!.items.first.isRead,isFalse);expect(c.value.unreadCount,1);
 });
 test('badge request completed after dispose is ignored',() async {
  final r=Repo();final c=NotificationCenterController(r);await c.loadInbox();r.badge=Completer();final pending=c.refreshUnreadCount();c.dispose();r.badge!.complete(9);await pending;
 });
 test('older badge cannot overwrite newer canonical inbox count',() async {
  final r=Repo();final c=NotificationCenterController(r);addTearDown(c.dispose);await c.loadInbox();final gate=Completer<int>();r.badge=gate;final pending=c.refreshUnreadCount();r.badge=null;r.items=[item('new'),item('old')];await c.loadInbox(silent:true);gate.complete(0);await pending;expect(c.value.unreadCount,2);
 });
 test('denial invalidates pending inbox and late successful mutation',() async {
  final r=Repo();final c=NotificationCenterController(r);addTearDown(c.dispose);await c.loadInbox();r.read=Completer();final pending=c.markRead('old');c.denyAccess();r.read!.complete(const MarkNotificationReadResult(notificationId:'old',isRead:true));await pending;expect(c.value.inbox,isNull);expect(c.value.unreadCount,0);
 });
 test('transient read retains inbox and bounded recovery eligibility clears on success',() async {
  final r=Repo();final c=NotificationCenterController(r);addTearDown(c.dispose);await c.loadInbox();r.failure=const NotificationFailure(code:'NETWORK',message:'offline',transportFailure:ApiTransportFailure.network);await c.loadInbox(silent:true);expect(c.value.inbox!.items.length,1);expect(c.readNeedsRecovery,isTrue);r.failure=null;r.items=[item('new')];await c.loadInbox(silent:true);expect(c.value.inbox!.items.single.notificationId,'new');expect(c.readNeedsRecovery,isFalse);
 });
 test('401 clears personal notification cache and is not transport recovery',() async {
  final r=Repo();final c=NotificationCenterController(r);addTearDown(c.dispose);await c.loadInbox();r.failure=const NotificationFailure(code:'DENIED',message:'denied',statusCode:401);await c.loadInbox(silent:true);expect(c.value.inbox,isNull);expect(c.readNeedsRecovery,isFalse);
 });

}
