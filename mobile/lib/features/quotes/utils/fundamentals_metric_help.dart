import 'package:flutter/material.dart';
import 'package:rico_investidor/features/quotes/models/stock_macro.dart';

class FundamentalsMetricHelp {
  const FundamentalsMetricHelp({
    required this.title,
    required this.description,
    this.calculation,
    this.interpretation,
  });

  final String title;
  final String description;
  final String? calculation;
  final String? interpretation;
}

/// Chaves do dicionário Brapi (`/v1/meta/dictionary`) por rótulo exibido no app.
const fundamentalsDictionaryKeys = <String, List<String>>{
  'DY 12m': ['dividendYield', 'yield'],
  'P/L': ['trailingPE', 'priceEarnings'],
  'P/VP': ['priceToBook'],
  'P/L fwd.': ['forwardPE', 'forwardPe'],
  'EV': ['enterpriseValue'],
  'EV/EBITDA': ['enterpriseToEbitda'],
  'Receita': ['totalRevenue'],
  'EBITDA': ['ebitda'],
  'FCF': ['freeCashflow'],
  'LPA': ['earningsPerShare'],
  'EPS': ['earningsPerShare'],
  'VP/cota': ['bookValuePerShare', 'bookValue'],
  'ROE': ['returnOnEquity'],
  'ROA': ['returnOnAssets'],
  'Margem líq.': ['profitMargins', 'profitMargin'],
  'Margem bruta': ['grossMargins', 'grossMargin'],
  'Margem oper.': ['operatingMargins', 'operatingMargin'],
  'Cresc. receita': ['revenueGrowth'],
  'Cresc. lucro': ['earningsGrowth'],
  'Dív./PL': ['debtToEquity'],
  'Caixa': ['totalCash'],
  'Dívida': ['totalDebt'],
  'Liquidez corr.': ['currentRatio'],
  'Payout': ['payoutRatio'],
  'Beta': ['beta'],
};

const _localHelp = <String, FundamentalsMetricHelp>{
  'DY 12m': FundamentalsMetricHelp(
    title: 'Dividend Yield (DY) 12m',
    description:
        'Percentual de proventos pagos nos últimos 12 meses em relação ao preço atual da ação. '
        'Mostra quanto a empresa distribuiu em dividendos/JCP para quem compra hoje.',
    calculation: 'DY = (proventos pagos em 12 meses ÷ preço atual) × 100',
    interpretation:
        'DY alto pode indicar boa renda, mas também empresa madura ou preço em queda. '
        'Compare com o histórico e com o setor.',
  ),
  'P/L': FundamentalsMetricHelp(
    title: 'Preço / Lucro (P/L)',
    description:
        'Quantas vezes o preço da ação está acima do lucro por ação. '
        'É um indicador de valuation: quanto o mercado paga por cada R\$ 1 de lucro.',
    calculation: 'P/L = preço da ação ÷ lucro por ação (LPA)',
    interpretation:
        'P/L baixo pode indicar ação barata (ou problemas). P/L alto pode refletir '
        'expectativa de crescimento. Compare com pares do mesmo setor.',
  ),
  'P/VP': FundamentalsMetricHelp(
    title: 'Preço / Valor Patrimonial (P/VP)',
    description:
        'Relaciona o preço de mercado com o valor contábil por ação (patrimônio líquido).',
    calculation: 'P/VP = preço da ação ÷ valor patrimonial por ação',
    interpretation:
        'P/VP abaixo de 1 sugere que o mercado negocia a empresa abaixo do patrimônio contábil. '
        'Acima de 1, o mercado paga prêmio sobre o balanço.',
  ),
  'P/L fwd.': FundamentalsMetricHelp(
    title: 'P/L projetado (forward)',
    description:
        'P/L calculado com lucro esperado para os próximos 12 meses, não o lucro já realizado.',
    calculation: 'P/L fwd. = preço da ação ÷ LPA estimado pelos analistas',
    interpretation:
        'Útil para empresas em recuperação ou com lucro volátil. '
        'Depende das estimativas do mercado — pode mudar com novos resultados.',
  ),
  'EV': FundamentalsMetricHelp(
    title: 'Enterprise Value (EV)',
    description:
        'Valor total da empresa para um comprador: capitalização + dívida líquida. '
        'Representa o custo econômico de assumir o negócio inteiro.',
    calculation: 'EV ≈ valor de mercado + dívida total − caixa',
    interpretation:
        'Complementa a capitalização quando a empresa tem muita dívida ou caixa relevante.',
  ),
  'EV/EBITDA': FundamentalsMetricHelp(
    title: 'EV / EBITDA',
    description:
        'Múltiplo de valuation que compara o valor da empresa (EV) com sua geração operacional (EBITDA).',
    calculation: 'EV/EBITDA = Enterprise Value ÷ EBITDA',
    interpretation:
        'Muito usado em comparações entre empresas do mesmo setor. '
        'Múltiplos menores podem indicar valuation mais atrativo.',
  ),
  'Receita': FundamentalsMetricHelp(
    title: 'Receita líquida',
    description: 'Faturamento total da empresa no período, antes de custos e despesas.',
    interpretation:
        'Crescimento consistente de receita é base para expansão de lucro. '
        'Analise junto com margens e rentabilidade.',
  ),
  'EBITDA': FundamentalsMetricHelp(
    title: 'EBITDA',
    description:
        'Lucro antes de juros, impostos, depreciação e amortização. '
        'Aproxima a geração de caixa operacional.',
    interpretation:
        'Ajuda a comparar empresas com estruturas de capital ou contábeis diferentes.',
  ),
  'FCF': FundamentalsMetricHelp(
    title: 'Fluxo de caixa livre (FCF)',
    description:
        'Caixa que sobra após investimentos necessários para manter e expandir o negócio.',
    calculation: 'FCF ≈ caixa operacional − investimentos (CAPEX)',
    interpretation:
        'FCF positivo sustenta dividendos, recompras e redução de dívida. '
        'Empresas com FCF recorrente costumam ser mais resilientes.',
  ),
  'LPA': FundamentalsMetricHelp(
    title: 'Lucro por ação (LPA)',
    description: 'Lucro líquido dividido pelo número de ações em circulação.',
    calculation: 'LPA = lucro líquido ÷ quantidade de ações',
    interpretation: 'Base do P/L. LPA crescente ao longo dos anos é sinal de ganho de escala ou eficiência.',
  ),
  'EPS': FundamentalsMetricHelp(
    title: 'Earnings Per Share (EPS)',
    description:
        'Lucro por ação — mesmo conceito do LPA, usado em mercados internacionais. '
        'Indica quanto de lucro cada ação gerou no período.',
    calculation: 'EPS = lucro líquido ÷ quantidade de ações',
    interpretation: 'Base do P/L. EPS em alta consistente reforça tese de crescimento de lucro.',
  ),
  'VP/cota': FundamentalsMetricHelp(
    title: 'Valor patrimonial por ação',
    description:
        'Patrimônio líquido (ativos − passivos) dividido pelo número de ações. '
        'É o “valor contábil” de cada ação.',
    calculation: 'VP/ação = patrimônio líquido ÷ ações em circulação',
    interpretation: 'Usado no P/VP. Não confundir com valor de mercado.',
  ),
  'ROE': FundamentalsMetricHelp(
    title: 'Return on Equity (ROE)',
    description:
        'Retorno sobre o patrimônio líquido: mede quanto lucro a empresa gera com o capital dos acionistas.',
    calculation: 'ROE = (lucro líquido ÷ patrimônio líquido) × 100',
    interpretation:
        'ROE consistente acima de 10–15% costuma ser visto como bom em muitos setores. '
        'ROE muito alto pode vir de alavancagem excessiva — veja a dívida.',
  ),
  'ROA': FundamentalsMetricHelp(
    title: 'Return on Assets (ROA)',
    description:
        'Retorno sobre os ativos totais: eficiência em gerar lucro com tudo que a empresa possui.',
    calculation: 'ROA = (lucro líquido ÷ ativos totais) × 100',
    interpretation:
        'Complementa o ROE. Setores intensivos em ativos (bancos, indústria pesada) '
        'tendem a ter ROA menor que empresas “leves”.',
  ),
  'Margem líq.': FundamentalsMetricHelp(
    title: 'Margem líquida',
    description: 'Percentual do lucro líquido em relação à receita. Mostra quanto sobra após todas as despesas.',
    calculation: 'Margem líquida = (lucro líquido ÷ receita) × 100',
    interpretation: 'Margens estáveis ou em alta indicam controle de custos e precificação saudável.',
  ),
  'Margem bruta': FundamentalsMetricHelp(
    title: 'Margem bruta',
    description: 'Receita menos custo direto dos produtos/serviços, em percentual da receita.',
    calculation: 'Margem bruta = ((receita − CPV) ÷ receita) × 100',
    interpretation: 'Quanto maior, mais folga a empresa tem para cobrir despesas operacionais e gerar lucro.',
  ),
  'Margem oper.': FundamentalsMetricHelp(
    title: 'Margem operacional',
    description: 'Lucro das operações (antes de financeiro e impostos) dividido pela receita.',
    calculation: 'Margem operacional = (lucro operacional ÷ receita) × 100',
    interpretation: 'Reflete a eficiência do core business, sem efeito de juros ou itens não recorrentes.',
  ),
  'Cresc. receita': FundamentalsMetricHelp(
    title: 'Crescimento da receita',
    description: 'Variação percentual da receita em relação ao período anterior (geralmente 12 meses).',
    interpretation: 'Crescimento sustentável com margens preservadas é mais valioso que crescimento “comprado” com margem menor.',
  ),
  'Cresc. lucro': FundamentalsMetricHelp(
    title: 'Crescimento do lucro',
    description: 'Variação percentual do lucro líquido em relação ao período anterior.',
    interpretation: 'Pode ser volátil em ciclos. Compare com crescimento de receita e margem.',
  ),
  'Dív./PL': FundamentalsMetricHelp(
    title: 'Dívida / Patrimônio líquido',
    description: 'Relação entre endividamento total e capital próprio. Mede alavancagem financeira.',
    calculation: 'Dívida/PL = dívida total ÷ patrimônio líquido',
    interpretation:
        'Valores altos aumentam risco em juros elevados. Setores como utilities e bancos '
        'têm padrões diferentes — compare com pares.',
  ),
  'Caixa': FundamentalsMetricHelp(
    title: 'Caixa e equivalentes',
    description: 'Recursos de alta liquidez disponíveis para operar, investir ou honrar compromissos.',
    interpretation: 'Caixa robusto dá colchão em crises e flexibilidade para oportunidades.',
  ),
  'Dívida': FundamentalsMetricHelp(
    title: 'Dívida total',
    description: 'Soma das obrigações financeiras da empresa (curto e longo prazo).',
    interpretation: 'Analise junto com caixa, EBITDA e custo da dívida (juros).',
  ),
  'Liquidez corr.': FundamentalsMetricHelp(
    title: 'Liquidez corrente',
    description: 'Capacidade de pagar obrigações de curto prazo com ativos circulantes.',
    calculation: 'Liquidez corrente = ativo circulante ÷ passivo circulante',
    interpretation: 'Acima de 1,0 indica cobertura básica do curto prazo. Muito acima pode indicar capital ocioso.',
  ),
  'Payout': FundamentalsMetricHelp(
    title: 'Payout',
    description:
        'Percentual do lucro distribuído em proventos. Mostra quanto a empresa paga vs quanto retém para reinvestir.',
    calculation: 'Payout = (dividendos pagos ÷ lucro líquido) × 100',
    interpretation:
        'Payout muito alto pode ser difícil de sustentar se o lucro cair. '
        'Payout moderado com DY atrativo é equilíbrio comum.',
  ),
  'Beta': FundamentalsMetricHelp(
    title: 'Beta',
    description:
        'Sensibilidade da ação em relação ao mercado (ex.: Ibovespa). '
        'Mede volatilidade relativa, não qualidade da empresa.',
    interpretation:
        'Beta ≈ 1 move junto com o índice. Beta > 1 amplifica altas e baixas. '
        'Beta < 1 tende a ser menos volátil que o mercado.',
  ),
  'Recomendação': FundamentalsMetricHelp(
    title: 'Recomendação dos analistas',
    description:
        'Consenso médio de casas de análise (compra, neutro, venda). '
        'Reflete expectativas do mercado, não recomendação do app.',
    interpretation: 'Use como referência, sempre junto com seus critérios e horizonte de investimento.',
  ),
  'Preço-alvo': FundamentalsMetricHelp(
    title: 'Preço-alvo médio',
    description: 'Média das projeções de preço feitas por analistas para os próximos 12 meses.',
    interpretation:
        'Pode mudar após balanços e eventos. Compare com o preço atual para ver o upside/downside implícito.',
  ),
  'Analistas': FundamentalsMetricHelp(
    title: 'Cobertura de analistas',
    description: 'Número de analistas que acompanham e publicam opinião sobre a empresa.',
    interpretation: 'Mais cobertura costuma significar mais liquidez de informação — mas não garante acerto.',
  ),
};

FundamentalsMetricHelp? resolveFundamentalsMetricHelp(
  String label,
  Map<String, DictionaryFieldDto> dictionary,
) {
  final keys = fundamentalsDictionaryKeys[label] ?? const [];
  DictionaryFieldDto? field;
  for (final key in keys) {
    final candidate = dictionary[key];
    if (candidate != null) {
      field = candidate;
      break;
    }
  }

  final local = _localHelp[label];
  if (field == null) return local;

  final apiDescription = field.description?.trim();
  if (apiDescription == null || apiDescription.isEmpty) return local;

  return FundamentalsMetricHelp(
    title: field.label?.trim().isNotEmpty == true ? field.label!.trim() : (local?.title ?? label),
    description: apiDescription,
    calculation: field.calculation?.trim().isNotEmpty == true
        ? field.calculation!.trim()
        : local?.calculation,
    interpretation: local?.interpretation,
  );
}

/// Roxo de ajuda — destaca o botão sem competir com o verde primário do app.
const Color fundamentalsHelpAccent = Color(0xFF7B5CF0);

/// Botão compacto estilo balão de mensagem com interrogação — leitura clara de ação.
class FundamentalsMetricHelpButton extends StatelessWidget {
  const FundamentalsMetricHelpButton({
    super.key,
    required this.onTap,
    this.tooltip,
  });

  static const double _bubbleWidth = 22;
  static const double _bubbleHeight = 17;
  static const double _tailHeight = 3.5;

  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = fundamentalsHelpAccent.withValues(alpha: isDark ? 0.22 : 0.1);
    final border = fundamentalsHelpAccent.withValues(alpha: isDark ? 0.75 : 0.6);

    final bubble = SizedBox(
      width: _bubbleWidth,
      height: _bubbleHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: const Size(_bubbleWidth, _bubbleHeight),
            painter: _FundamentalsHelpBubblePainter(
              fillColor: fill,
              borderColor: border,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _bubbleHeight - _tailHeight,
            child: Center(
              child: Text(
                '?',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  color: fundamentalsHelpAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: tooltip != null ? 'Explicar $tooltip' : 'Explicar métrica',
      child: Tooltip(
        message: 'O que significa?',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            splashColor: fundamentalsHelpAccent.withValues(alpha: 0.18),
            highlightColor: fundamentalsHelpAccent.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: bubble,
            ),
          ),
        ),
      ),
    );
  }
}

class _FundamentalsHelpBubblePainter extends CustomPainter {
  const _FundamentalsHelpBubblePainter({
    required this.fillColor,
    required this.borderColor,
  });

  final Color fillColor;
  final Color borderColor;

  static const double _radius = 4.5;
  static const double _tailHeight = FundamentalsMetricHelpButton._tailHeight;

  Path _bubblePath(Size size) {
    final bodyBottom = size.height - _tailHeight;
    final tailLeft = size.width * 0.28;
    final tailTipX = size.width * 0.14;
    final tailRight = size.width * 0.46;

    final path = Path();
    path.moveTo(_radius, 0);
    path.lineTo(size.width - _radius, 0);
    path.arcToPoint(
      Offset(size.width, _radius),
      radius: const Radius.circular(_radius),
    );
    path.lineTo(size.width, bodyBottom - _radius);
    path.arcToPoint(
      Offset(size.width - _radius, bodyBottom),
      radius: const Radius.circular(_radius),
    );
    path.lineTo(tailRight, bodyBottom);
    path.lineTo(tailTipX, size.height);
    path.lineTo(tailLeft, bodyBottom);
    path.lineTo(_radius, bodyBottom);
    path.arcToPoint(
      Offset(0, bodyBottom - _radius),
      radius: const Radius.circular(_radius),
    );
    path.lineTo(0, _radius);
    path.arcToPoint(
      const Offset(_radius, 0),
      radius: const Radius.circular(_radius),
    );
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _bubblePath(size);

    canvas.drawPath(
      path,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _FundamentalsHelpBubblePainter oldDelegate) {
    return oldDelegate.fillColor != fillColor || oldDelegate.borderColor != borderColor;
  }
}

Future<void> showFundamentalsMetricHelpDialog(
  BuildContext context,
  FundamentalsMetricHelp help,
) {
  final theme = Theme.of(context);

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                help.title,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Fechar',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'O que é',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                help.description,
                style: theme.textTheme.bodyMedium,
              ),
              if (help.calculation != null) ...[
                const SizedBox(height: 14),
                Text(
                  'Como é calculado',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  help.calculation!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ],
              if (help.interpretation != null) ...[
                const SizedBox(height: 14),
                Text(
                  'Como interpretar',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  help.interpretation!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendi'),
          ),
        ],
      );
    },
  );
}
