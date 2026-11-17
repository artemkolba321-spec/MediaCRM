import 'package:uuid/uuid.dart';

import 'package:media_crm/data/cloud/cloud_service.dart';
import 'package:media_crm/data/local/local_store.dart';
import 'package:media_crm/data/models/funnel.dart';
import 'package:media_crm/data/repositories/entity_repository.dart';

class FunnelRepository {
  FunnelRepository({
    required LocalStore store,
    required CloudService cloud,
    required ActivityService activity,
  }) {
    _funnels = EntityRepository<Funnel>(
      store: store,
      cloud: cloud,
      collection: 'funnels',
      fromJson: Funnel.fromJson,
      toJson: (e) => e.toJson(),
      idOf: (e) => e.id,
      userIdOf: (e) => e.userId,
      updatedAtOf: (e) => e.updatedAt,
      activity: activity,
    );
    _stages = EntityRepository<FunnelStage>(
      store: store,
      cloud: cloud,
      collection: 'stages',
      fromJson: FunnelStage.fromJson,
      toJson: (e) => e.toJson(),
      idOf: (e) => e.id,
      userIdOf: (e) => e.userId,
      updatedAtOf: (_) => DateTime.now(),
    );
    _deals = EntityRepository<FunnelDeal>(
      store: store,
      cloud: cloud,
      collection: 'deals',
      fromJson: FunnelDeal.fromJson,
      toJson: (e) => e.toJson(),
      idOf: (e) => e.id,
      userIdOf: (e) => e.userId,
      updatedAtOf: (e) => e.updatedAt,
      activity: activity,
    );
  }

  late final EntityRepository<Funnel> _funnels;
  late final EntityRepository<FunnelStage> _stages;
  late final EntityRepository<FunnelDeal> _deals;
  final _uuid = const Uuid();

  List<Funnel> getFunnels() => _funnels.getAll()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Funnel? getFunnel(String id) => _funnels.getById(id);

  Future<Funnel> saveFunnel(Funnel funnel) => _funnels.save(
        funnel,
        actionLabel: 'updated',
        title: 'Воронка «${funnel.name}»',
      );

  Future<void> deleteFunnel(Funnel funnel) async {
    for (final stage in getStages(funnel.id)) {
      await _stages.delete(stage.id);
    }
    for (final deal in getDeals(funnel.id)) {
      await _deals.delete(deal.id);
    }
    await _funnels.delete(
      funnel.id,
      title: 'Удалена воронка «${funnel.name}»',
    );
  }

  List<FunnelStage> getStages(String funnelId) => _stages
      .getAll()
      .where((s) => s.funnelId == funnelId)
      .toList()
    ..sort((a, b) => a.order.compareTo(b.order));

  Future<FunnelStage> saveStage(FunnelStage stage) =>
      _stages.save(stage, actionLabel: 'updated', title: 'Этап «${stage.name}»');

  Future<void> deleteStage(FunnelStage stage) async {
    for (final deal in getDeals(stage.funnelId)
        .where((d) => d.stageId == stage.id)) {
      await _deals.delete(deal.id);
    }
    await _stages.delete(stage.id);
  }

  List<FunnelDeal> getDeals(String funnelId, {String? stageId}) {
    var items = _deals.getAll().where((d) => d.funnelId == funnelId);
    if (stageId != null) items = items.where((d) => d.stageId == stageId);
    final list = items.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<FunnelDeal> saveDeal(FunnelDeal deal) => _deals.save(
        deal,
        actionLabel: 'updated',
        title: 'Сделка «${deal.contactName}»',
      );

  Future<FunnelDeal?> moveDeal(FunnelDeal deal, String newStageId) async {
    if (deal.stageId == newStageId) return deal;
    final now = DateTime.now();
    final updated = deal.copyWith(
      stageId: newStageId,
      movedAt: now,
      updatedAt: now,
    );
    await _deals.save(updated, actionLabel: 'moved', title: 'Сделка перемещена');
    return updated;
  }

  Future<void> deleteDeal(FunnelDeal deal) => _deals.delete(
        deal.id,
        title: 'Удалена сделка «${deal.contactName}»',
      );

  List<FunnelStageMetrics> metrics(String funnelId) =>
      calculateFunnelMetrics(getStages(funnelId), getDeals(funnelId));

  String generateStageId() => _uuid.v4();
}
