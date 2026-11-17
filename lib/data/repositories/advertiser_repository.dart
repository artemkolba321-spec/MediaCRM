import 'package:uuid/uuid.dart';

import 'package:media_crm/core/analytics/analytics_calculator.dart';
import 'package:media_crm/data/models/analytics_snapshot.dart';
import 'package:media_crm/data/cloud/cloud_service.dart';
import 'package:media_crm/data/local/local_store.dart';
import 'package:media_crm/data/models/advertiser.dart';
import 'package:media_crm/data/models/financial_operation.dart';
import 'package:media_crm/data/models/platform_channel.dart';
import 'package:media_crm/data/models/user_settings.dart';
import 'package:media_crm/data/repositories/channel_repository.dart';
import 'package:media_crm/data/repositories/entity_repository.dart';
import 'package:media_crm/data/repositories/finance_repository.dart';
import 'package:media_crm/data/repositories/publication_repository.dart';

class CampaignReport {
  final AdCampaign campaign;
  final double views;
  final double reach;
  final int publications;
  final double audienceAtEnd;
  final double audienceGrowth;
  final bool derived;

  const CampaignReport({
    required this.campaign,
    required this.views,
    required this.reach,
    required this.publications,
    required this.audienceAtEnd,
    required this.audienceGrowth,
    this.derived = true,
  });
}

class AdvertiserRepository {
  AdvertiserRepository({
    required LocalStore store,
    required CloudService cloud,
    required ActivityService activity,
    required FinanceRepository finance,
    required ChannelRepository channels,
    required PublicationRepository publications,
  })  : _finance = finance,
        _channels = channels,
        _publications = publications {
    _advertisers = EntityRepository<Advertiser>(
      store: store,
      cloud: cloud,
      collection: 'advertisers',
      fromJson: Advertiser.fromJson,
      toJson: (e) => e.toJson(),
      idOf: (e) => e.id,
      userIdOf: (e) => e.userId,
      updatedAtOf: (e) => e.updatedAt,
      activity: activity,
    );
    _campaigns = EntityRepository<AdCampaign>(
      store: store,
      cloud: cloud,
      collection: 'campaigns',
      fromJson: AdCampaign.fromJson,
      toJson: (e) => e.toJson(),
      idOf: (e) => e.id,
      userIdOf: (e) => e.userId,
      updatedAtOf: (e) => e.updatedAt,
      activity: activity,
    );
    _notes = EntityRepository<AdvertiserNote>(
      store: store,
      cloud: cloud,
      collection: 'advertiser_notes',
      fromJson: AdvertiserNote.fromJson,
      toJson: (e) => e.toJson(),
      idOf: (e) => e.id,
      userIdOf: (e) => e.userId,
      updatedAtOf: (e) => e.createdAt,
    );
    _documents = EntityRepository<CampaignDocument>(
      store: store,
      cloud: cloud,
      collection: 'campaign_documents',
      fromJson: CampaignDocument.fromJson,
      toJson: (e) => e.toJson(),
      idOf: (e) => e.id,
      userIdOf: (e) => e.userId,
      updatedAtOf: (e) => e.createdAt,
    );
  }

  final FinanceRepository _finance;
  final ChannelRepository _channels;
  final PublicationRepository _publications;
  late final EntityRepository<Advertiser> _advertisers;
  late final EntityRepository<AdCampaign> _campaigns;
  late final EntityRepository<AdvertiserNote> _notes;
  late final EntityRepository<CampaignDocument> _documents;
  final _uuid = const Uuid();

  List<Advertiser> getAdvertisers({String? search, AdvertiserStatus? status}) {
    var items = _advertisers.getAll();
    if (status != null) items = items.where((a) => a.status == status).toList();
    if (search != null && search.trim().isNotEmpty) {
      final q = search.toLowerCase();
      items = items
          .where((a) =>
              a.companyName.toLowerCase().contains(q) ||
              (a.contactPerson ?? '').toLowerCase().contains(q) ||
              (a.email ?? '').toLowerCase().contains(q))
          .toList();
    }
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  Advertiser? getAdvertiser(String id) => _advertisers.getById(id);

  Future<Advertiser> saveAdvertiser(Advertiser advertiser) async {
    final isNew = _advertisers.getById(advertiser.id) == null;
    return _advertisers.save(
      advertiser,
      actionLabel: isNew ? 'created' : 'updated',
      title: isNew
          ? 'Добавлен рекламодатель «${advertiser.companyName}»'
          : 'Обновлён рекламодатель «${advertiser.companyName}»',
    );
  }

  Future<void> deleteAdvertiser(Advertiser advertiser) async {
    for (final campaign in getCampaigns(advertiserId: advertiser.id)) {
      await deleteCampaign(campaign);
    }
    for (final note in getNotes(advertiser.id)) {
      await _notes.delete(note.id);
    }
    await _advertisers.delete(
      advertiser.id,
      title: 'Удалён рекламодатель «${advertiser.companyName}»',
    );
  }

  List<AdCampaign> getCampaigns({
    String? advertiserId,
    CampaignStatus? status,
    bool activeOnly = false,
  }) {
    var items = _campaigns.getAll();
    if (advertiserId != null) {
      items = items.where((c) => c.advertiserId == advertiserId).toList();
    }
    if (status != null) items = items.where((c) => c.status == status).toList();
    if (activeOnly) {
      items = items.where((c) => c.status == CampaignStatus.active).toList();
    }
    items.sort((a, b) => b.startDate.compareTo(a.startDate));
    return items;
  }

  AdCampaign? getCampaign(String id) => _campaigns.getById(id);

  Future<AdCampaign> saveCampaign(AdCampaign campaign) async {
    final isNew = _campaigns.getById(campaign.id) == null;
    return _campaigns.save(
      campaign,
      actionLabel: isNew ? 'created' : 'updated',
      title: isNew
          ? 'Создана рекламная кампания «${campaign.name}»'
          : 'Обновлена кампания «${campaign.name}»',
    );
  }

  Future<void> deleteCampaign(AdCampaign campaign) async {
    for (final doc in getDocuments(campaign.id)) {
      await _documents.delete(doc.id);
    }
    await _campaigns.delete(
      campaign.id,
      title: 'Удалена кампания «${campaign.name}»',
    );
  }

  double totalDebt({String? advertiserId}) {
    return getCampaigns(advertiserId: advertiserId).fold<double>(
      0,
      (sum, campaign) => sum + campaign.debt * campaign.exchangeRate,
    );
  }

  double advertiserRevenue(String advertiserId, {DateTime? start, DateTime? end}) {
    return _finance
        .getOperations(FinanceFilter(
          start: start,
          end: end,
          advertiserId: advertiserId,
          types: const {TransactionType.income},
        ))
        .fold<double>(0, (sum, op) => sum + op.baseAmount);
  }

  List<AdvertiserNote> getNotes(String advertiserId) {
    final items = _notes
        .getAll()
        .where((n) => n.advertiserId == advertiserId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<AdvertiserNote> addNote(Advertiser advertiser, String text) async {
    if (text.trim().isEmpty) {
      throw ArgumentError('Текст заметки пуст');
    }
    final note = AdvertiserNote(
      id: _uuid.v4(),
      userId: advertiser.userId,
      advertiserId: advertiser.id,
      text: text.trim(),
      createdAt: DateTime.now(),
    );
    await _notes.append(note);
    await _advertisers.save(advertiser.copyWith(updatedAt: DateTime.now()));
    return note;
  }

  Future<void> deleteNote(AdvertiserNote note) => _notes.delete(note.id);

  List<CampaignDocument> getDocuments(String campaignId) {
    final items = _documents
        .getAll()
        .where((d) => d.campaignId == campaignId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<CampaignDocument> addDocument({
    required AdCampaign campaign,
    required String name,
    String? url,
    String? notes,
  }) async {
    final doc = CampaignDocument(
      id: _uuid.v4(),
      userId: campaign.userId,
      advertiserId: campaign.advertiserId,
      campaignId: campaign.id,
      name: name.trim(),
      url: url,
      notes: notes,
      createdAt: DateTime.now(),
    );
    await _documents.append(doc);
    return doc;
  }

  Future<void> deleteDocument(CampaignDocument document) =>
      _documents.delete(document.id);

  /// Records a received payment as an income operation and updates the paid
  /// amount on the campaign. It does not move real money.
  Future<FinancialOperation> recordPayment({
    required AdCampaign campaign,
    required double amount,
    required UserSettings settings,
    DateTime? date,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Сумма оплаты должна быть больше нуля');
    }
    final now = DateTime.now();
    final operation = FinancialOperation(
      id: _uuid.v4(),
      userId: campaign.userId,
      type: TransactionType.income,
      status: TransactionStatus.completed,
      amount: amount,
      currency: campaign.currency,
      exchangeRate: campaign.exchangeRate,
      baseAmount: amount * campaign.exchangeRate,
      baseCurrency: settings.baseCurrency,
      category: TransactionCategory.adRevenue,
      description: 'Оплата рекламной кампании «${campaign.name}»',
      counterparty: getAdvertiser(campaign.advertiserId)?.companyName,
      advertiserId: campaign.advertiserId,
      campaignId: campaign.id,
      channelId:
          campaign.channelIds.length == 1 ? campaign.channelIds.first : null,
      date: date ?? now,
      createdAt: now,
      updatedAt: now,
    );
    await _finance.saveOperation(operation);
    await _campaigns.save(campaign.copyWith(
      paidAmount: campaign.paidAmount + amount,
      status: campaign.paidAmount + amount >= campaign.budget
          ? CampaignStatus.completed
          : campaign.status,
      updatedAt: now,
    ));
    return operation;
  }

  /// Reach report is derived from saved analytics snapshots for the channels
  /// selected in the campaign. It is explicitly marked as derived.
  CampaignReport campaignReport(AdCampaign campaign) {
    final channelIds = campaign.channelIds.toSet();
    final channels = _channels
        .getChannels()
        .where((c) => channelIds.contains(c.id))
        .toList();
    final snapshots = _channels.getSnapshots(
      start: campaign.startDate,
      end: campaign.endDate,
    );
    final views = snapshots
        .where((s) =>
            s.metric == AnalyticsMetric.views &&
            channelIds.contains(s.channelId))
        .fold<double>(0, (sum, s) => sum + s.value);
    final reach = snapshots
        .where((s) =>
            s.metric == AnalyticsMetric.reach &&
            channelIds.contains(s.channelId))
        .fold<double>(0, (sum, s) => sum + s.value);
    final publications = _publications
        .publicationsInPeriod(campaign.startDate, campaign.endDate)
        .where((p) => channelIds.contains(p.channelId))
        .length;
    final audienceEnd = audienceAt(channels, snapshots, campaign.endDate);
    final audienceStart = audienceAt(
      channels,
      snapshots,
      campaign.startDate.subtract(const Duration(days: 1)),
    );
    return CampaignReport(
      campaign: campaign,
      views: views,
      reach: reach,
      publications: publications,
      audienceAtEnd: audienceEnd,
      audienceGrowth: audienceEnd - audienceStart,
    );
  }

  int campaignPublications(AdCampaign campaign) => _publications
      .publicationsInPeriod(campaign.startDate, campaign.endDate)
      .where((p) => campaign.channelIds.contains(p.channelId))
      .length;

  List<PlatformChannel> channelsFor(AdCampaign campaign) => _channels
      .getChannels()
      .where((c) => campaign.channelIds.contains(c.id))
      .toList();
}
