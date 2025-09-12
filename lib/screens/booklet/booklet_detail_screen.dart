import 'package:flutter/material.dart';
import '../../models/booklet_model.dart';
import '../../theme.dart';

class BookletDetailScreen extends StatefulWidget {
  final Booklet booklet;

  const BookletDetailScreen({super.key, required this.booklet});

  @override
  State<BookletDetailScreen> createState() => _BookletDetailScreenState();
}

class _BookletDetailScreenState extends State<BookletDetailScreen> {
  String _searchQuery = '';
  String _statusFilter = 'All';

  List<FuelSlip> get _filteredSlips {
    final slips = widget.booklet.fuelSlips;
    Iterable<FuelSlip> result = slips;

    // Status filter
    if (_statusFilter != 'All') {
      result = result.where((s) {
        switch (_statusFilter) {
          case 'Available':
            return s.isAvailable && !s.isUsed && !s.isCancelled && !s.isLost;
          case 'Used':
            return s.isUsed;
          case 'Cancelled':
            return s.isCancelled;
          case 'Lost':
            return s.isLost;
          default:
            return true;
        }
      });
    }

    // Search by slip number
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.trim();
      result = result.where((s) => s.slipNumber.toString().contains(q));
    }

    // Sort by slip number ascending
    final list = result.toList();
    list.sort((a, b) => a.slipNumber.compareTo(b.slipNumber));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Booklet ${widget.booklet.bookletNumber}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildControls()),
          _buildSlipsList(),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final b = widget.booklet;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.book_rounded, color: AppTheme.primaryBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Booklet #${b.bookletNumber}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${b.customerName.trim()} (${b.customerCode})',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (b.isCompleted ? Colors.green : (b.isActive ? Colors.blue : Colors.grey)).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  b.isCompleted ? 'Completed' : (b.isActive ? 'Active' : 'Inactive'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: b.isCompleted ? Colors.green : (b.isActive ? Colors.blue : Colors.grey),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _chipStat('Total', b.totalSlips.toString(), Colors.blue),
              const SizedBox(width: 8),
              _chipStat('Used', b.usedSlips.toString(), Colors.green),
              const SizedBox(width: 8),
              _chipStat('Available', b.availableSlips.toString(), Colors.orange),
              const Spacer(),
              _chipStat('${b.slipRangeStart} - ${b.slipRangeEnd}', 'Range', Colors.purple, invert: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipStat(String label, String value, Color color, {bool invert = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: invert ? color : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: invert ? Colors.white : color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: invert ? Colors.white.withValues(alpha: 0.9) : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Search slip number...',
                  hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade600, size: 22),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () => setState(() => _searchQuery = ''),
                          icon: Icon(Icons.clear_rounded, color: Colors.grey.shade600, size: 20),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Status filter dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _statusFilter,
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All')),
                  DropdownMenuItem(value: 'Available', child: Text('Available')),
                  DropdownMenuItem(value: 'Used', child: Text('Used')),
                  DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                  DropdownMenuItem(value: 'Lost', child: Text('Lost')),
                ],
                onChanged: (v) => setState(() => _statusFilter = v ?? 'All'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(FuelSlip slip) {
    Color color;
    String label;
    if (slip.isUsed) {
      color = Colors.green;
      label = 'Used';
    } else if (slip.isCancelled) {
      color = Colors.red;
      label = 'Cancelled';
    } else if (slip.isLost) {
      color = Colors.orange;
      label = 'Lost';
    } else {
      color = Colors.blue;
      label = 'Available';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildSlipsList() {
    final slips = _filteredSlips;

    if (slips.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_rounded, size: 40, color: Colors.blue.shade400),
              const SizedBox(height: 12),
              Text(
                'No slips match your filters',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 6),
              Text(
                'Try adjusting search or status.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList.builder(
      itemCount: slips.length,
      itemBuilder: (context, index) {
        final slip = slips[index];
        return Container(
          margin: EdgeInsets.fromLTRB(16, index == 0 ? 8 : 6, 16, 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.receipt_long_rounded, color: AppTheme.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#${slip.slipNumber}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(slip),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (slip.usedDate != null)
                          _meta('Used', _formatDateTime(slip.usedDate!)),
                        if (slip.vehicleTransactionId != null)
                          _meta('Txn', slip.vehicleTransactionId!.substring(0, 8)),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        );
      },
    );
  }

  Widget _meta(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade800, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}


