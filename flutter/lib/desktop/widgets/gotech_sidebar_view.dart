import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'gotech_tokens.dart';
import 'gotech_view_parts.dart';

// The GoTech sidebar drawn from plain data: tabs and companies. gotech_sidebar.dart feeds it real data.

const _kTabular = [FontFeature.tabularFigures()];

/// One peer tab in the sidebar.
class GoTechNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const GoTechNavItem({
    Key? key,
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = GoTechColors.of(context);
    final color = selected ? c.fg : c.muted;
    return Material(
      color: selected ? c.raised : Colors.transparent,
      borderRadius: BorderRadius.circular(kGoTechNavRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(kGoTechNavRadius),
        hoverColor: c.hover,
        onTap: onTap,
        child: Padding(
          padding: kGoTechNavPadding,
          child: Row(children: [
            Icon(icon, size: kGoTechNavIconSize, color: color),
            const SizedBox(width: kGoTechColumnGap),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: kGoTechFontBody,
                      fontWeight: FontWeight.w500,
                      color: color)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A company (address book tag) in the sidebar list.
class GoTechCompanyData {
  final String tag;
  final String name;
  final Color? color;
  final int count;
  final bool dim;
  const GoTechCompanyData(
      {required this.tag,
      required this.name,
      required this.count,
      this.color,
      this.dim = false});
}

class _CompanyItem extends StatelessWidget {
  final String name;
  final Color? color;
  final int count;
  final bool selected;
  final bool dim;
  final VoidCallback onTap;

  const _CompanyItem({
    required this.name,
    required this.color,
    required this.count,
    required this.selected,
    required this.dim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = GoTechColors.of(context);
    return Opacity(
      opacity: dim ? kGoTechDimOpacity : 1,
      child: Material(
        color: selected ? c.raised : Colors.transparent,
        borderRadius: BorderRadius.circular(kGoTechCompanyRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(kGoTechCompanyRadius),
          hoverColor: c.hover,
          onTap: onTap,
          child: Padding(
            padding: kGoTechCompanyPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: kGoTechDotSize,
                  child: color == null
                      ? null
                      : GoTechColorDot(color: color!)
                          .marginOnly(top: kGoTechCompanyDotTop),
                ),
                const SizedBox(width: kGoTechColumnGap - 1),
                // full names wrap: long legal names are how the customers are told apart
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontSize: kGoTechFontId,
                          fontWeight: FontWeight.w500,
                          height: kGoTechLineHeight)),
                ),
                const SizedBox(width: kGoTechColumnGap - 1),
                Text('$count',
                        style: TextStyle(
                            fontSize: kGoTechFontSmall,
                            color: c.muted,
                            fontFeatures: _kTabular))
                    .marginOnly(top: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Tüm bilgisayarlar", then the companies, nested under Rehber with a thin guide line. [selected] is the
/// selected tag, or null for all computers.
class GoTechCompanyList extends StatelessWidget {
  final int allCount;
  final List<GoTechCompanyData> companies;
  final String? selected;
  final ValueChanged<String?> onSelect;

  const GoTechCompanyList({
    Key? key,
    required this.allCount,
    required this.companies,
    required this.selected,
    required this.onSelect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = GoTechColors.of(context);
    return Container(
      margin: const EdgeInsets.only(left: kGoTechCompanyIndent),
      padding: const EdgeInsets.only(left: kGoTechCompanyGuidePadding),
      decoration:
          BoxDecoration(border: Border(left: BorderSide(color: c.line))),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: kGoTechNavGap),
        children: [
          _CompanyItem(
            name: 'Tüm bilgisayarlar',
            color: null,
            count: allCount,
            selected: selected == null,
            dim: false,
            onTap: () => onSelect(null),
          ),
          Container(
            margin: const EdgeInsets.only(top: kGoTechDropGap),
            padding: kGoTechCompanyHeaderPadding,
            decoration:
                BoxDecoration(border: Border(top: BorderSide(color: c.line))),
            child: Text('Firmalar',
                style: TextStyle(fontSize: kGoTechFontTiny, color: c.faint)),
          ),
          for (final co in companies)
            _CompanyItem(
              name: co.name,
              color: co.color,
              count: co.count,
              selected: selected == co.tag,
              dim: co.dim,
              onTap: () => onSelect(co.tag),
            ),
        ],
      ),
    );
  }
}

/// The sidebar frame: header, tabs (with the company list under the address book), footer pinned below.
class GoTechSidebarView extends StatelessWidget {
  final Widget header;
  final List<Widget> nav;

  /// Shown right after `nav[companiesAfter]`, taking the free height.
  final Widget? companies;
  final int companiesAfter;
  final List<Widget> footer;

  const GoTechSidebarView({
    Key? key,
    required this.header,
    required this.nav,
    required this.footer,
    this.companies,
    this.companiesAfter = -1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = GoTechColors.of(context);
    final hasCompanies = companies != null && companiesAfter >= 0;
    return Container(
      width: kGoTechSidebarWidth,
      padding: kGoTechSidebarPadding,
      decoration: BoxDecoration(
        color: c.sidebar,
        border: Border(right: BorderSide(color: c.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: kGoTechSidebarGap),
          for (var i = 0; i < nav.length; i++) ...[
            nav[i].marginOnly(bottom: kGoTechNavGap),
            if (hasCompanies && i == companiesAfter)
              Expanded(child: companies!),
          ],
          if (!hasCompanies) const Spacer(),
          const SizedBox(height: kGoTechDropGap),
          for (final w in footer) w.marginOnly(top: kGoTechDropGap),
        ],
      ),
    );
  }
}
