abstract final class LegalContent {
  static const aboutTitle = 'Sobre o Rico Investidor';
  static const aboutBody = '''
O Rico Investidor é um aplicativo de acompanhamento de investimentos focado em ações americanas e criptomoedas.

**O que fazemos**
- Exibimos cotações, gráficos e fundamentos de ativos
- Permite organizar sua carteira e acompanhar dividendos
- Oferecemos ferramentas de análise educacional

**O que NÃO fazemos**
- Não somos corretora nem intermediamos ordens
- Não recomendamos compra, venda ou manutenção de ativos
- Não garantimos precisão absoluta dos dados de mercado

**Fontes de dados**
- Ações EUA: Marketstack, Financial Modeling Prep
- Criptomoedas: Binance, CoinGecko (fallback)
- Logos: CoinCap e provedores públicos

**Contato**
Suporte: suporte@ricoinvestidor.app

Versão do app exibida em Configurações → Ajuda.
''';

  static const privacyTitle = 'Política de Privacidade';
  static const privacyBody = '''
**Última atualização:** junho de 2026

**1. Dados que coletamos**
- Conta: e-mail, nome, senha (hash), foto de perfil opcional
- Carteira: ativos, quantidades e transações que você informa
- Dispositivo: identificador anônimo para sessão convidado
- Preferências: tema, idioma, alertas

**2. Como usamos**
- Autenticar e sincronizar sua carteira
- Exibir cotações e alertas configurados por você
- Melhorar estabilidade e segurança do serviço

**3. Armazenamento**
- Dados de conta e carteira: servidor seguro (PostgreSQL)
- Foto de perfil: servidor (máx. 2 MB, JPEG/PNG)
- Preferências locais: armazenamento do dispositivo

**4. Compartilhamento**
Não vendemos seus dados. APIs de mercado recebem apenas símbolos consultados, sem dados pessoais.

**5. Seus direitos**
Você pode excluir sua conta em Configurações. Isso remove dados da conta, carteira e finanças vinculadas.

**6. Contato**
privacidade@ricoinvestidor.app
''';

  static const termsTitle = 'Termos de Uso';
  static const termsBody = '''
**Última atualização:** junho de 2026

**1. Aceitação**
Ao usar o Rico Investidor você concorda com estes termos.

**2. Natureza do serviço**
O app fornece **informações** sobre ativos financeiros. **Não constitui assessoria de investimentos**, recomendação de compra/venda, ou oferta de valores mobiliários.

**3. Responsabilidade do usuário**
Decisões de investimento são de sua exclusiva responsabilidade. Consulte profissionais qualificados quando necessário.

**4. Dados de mercado**
Cotações podem ter atraso, erros ou indisponibilidade temporária. Não garantimos exatidão em tempo real.

**5. Conta**
Você é responsável por manter sua senha segura. Contas podem ser encerradas por violação destes termos.

**6. Publicidade**
A versão gratuita exibe anúncios (Google AdMob). Assinaturas futuras podem remover anúncios.

**7. Limitação de responsabilidade**
Na máxima extensão permitida por lei, não respondemos por perdas financeiras decorrentes do uso do app.

**8. Lei aplicável**
Legislação brasileira, foro da comarca do usuário consumidor quando aplicável.

**9. Contato**
legal@ricoinvestidor.app
''';
}
