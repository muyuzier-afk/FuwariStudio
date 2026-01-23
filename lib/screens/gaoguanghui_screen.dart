import 'package:flutter/material.dart';

class GaoGuangHuiScreen extends StatelessWidget {
  const GaoGuangHuiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('高广辉')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '高广辉',
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: cs.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '纪念',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _statement,
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '简要概况',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            _summary,
            style: textTheme.bodyMedium?.copyWith(height: 1.35),
          ),
          const SizedBox(height: 12),
          Text(
            '资料摘录',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '（可复制；为你提供的材料原文，未做核实）',
            style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          const ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text('展开/收起'),
            children: [
              SelectableText(_gaoguanghuiContent),
            ],
          ),
        ],
      ),
    );
  }
}

const String _statement = '''
FuwariStudio 开源社区谨以此页纪念高广辉。

据相关报道与家属讲述，他在高强度工作与无边界加班压力下离世。我们对视源股份在相关事件中所呈现出的用工管理与加班文化表示强烈谴责，并向遗孀及家属致以最深切的慰问与支持。

愿逝者安息，愿每一位劳动者都能被善待、被保护。''';

const String _summary = '''
高广辉（据称 32 岁）早年随父母从河南来到广东，大学就读于软件学院，长期兼职维持生活；工作后晋升为部门经理。

据材料描述：事发前工作日多次晚归；事发周六家中处理工作并打开公司 OA 系统，随后突发不适被送医抢救无效。抢救期间仍被拉入工作群，死亡后仍收到催改需求。家属已申请工伤认定。''';

const String _gaoguanghuiContent = '''
高广辉，早年跟随父母从河南来到广东，童年时曾捡垃圾换取零用钱，大学就读于软件学院，多次兼职缓解拮据，与同校的爱人结婚，至今未育。在公司里，他被晋升为部门经理，猝死前一周的工作日，他最早到家时间为21:38，最晚为22:47。猝死当天是周六，部门有4项工作任务到了截止日，他打开过公司OA系统。抢救期间，他被拉入了一个工作群内。死亡后，有不知情的同事发来消息，拜托他“要把这个改下”。

120院前医疗急救病历中，既往史提及“程序员经常熬夜”。在转院至广东省第二中医院后，既往史标注“患者家属诉患者为程序员，平时工作强度大压力大”。

据高广辉的家人李女士（化姓）介绍，高广辉是个努力、上进的人，他在河南长大，到了十岁左右，跟着家人来到了广东，“以前家里条件困难，没有零花钱了，是捡垃圾去卖钱”。他大学就读于广州软件学院，期间做兼职挣生活费，“室友说他很拮据”。在他16岁时，曾在日记里写：“命运和挫折让我慢慢成长，心理和生理的变化让我清醒，看透生活，分析未来，是努力，努力再努力。”

李女士曾陪同高广辉在公司加班，见过他的工位。照片里，他的工位上有三块屏幕，摆放着婚纱照以及荣誉证书，桌下放着拖鞋，“还有行军床，用来午休。”他获得过一座奖杯、一块“编程马拉松”奖牌，九张奖状。工作努力的他，还是个热心肠。据身边人回忆，当他看到有人被抢了包，就和同学追过去，摁下了小偷。

8:58 拨打120
13:00 宣告死亡
死因：呼吸心跳骤停

高广辉的家人李女士（化姓）记得，2025年11月29日上午，他起得很早，“他说他有点不舒服，要到客厅那坐一会儿，顺便处理一下工作。”李女士又睡了过去，迷迷糊糊中，她又听到高广辉叫自己，来到客厅后发现他坐在地上，“他说他刚刚好像晕倒了，站不起来了，还说自己好像尿失禁了。”李女士决定带他去医院。

就医记录显示，高广辉“反复意识障碍后至昏迷”，8:58，120收到了来电；约9:14，120到达现场；9:46，他被转送至广东省第二中医院，“考虑已临床死亡，患者家属要求积极抢救”，“起病急，病程短，病情凶险”；抢救至13:00，宣告临床死亡，死亡原因“呼吸心跳骤停，阿斯综合征？”。

抢救期间被拉入工作群
死亡后有工作消息
已向人社局申请工伤

李女士记得，当天她使用了高广辉的手机，看到手机界面中带有公司的标志，但她在情急之下退出了页面，目前还不确定她看到的页面是什么。浏览器记录显示，当天，高广辉至少5次访问了公司OA系统，但未显示具体时间。

29日事发当日是周六，他的私人微信仍在接收工作消息。10:48，在医院积极抢救中，他被拉入了一个微信技术群中，11:15，一名群成员发消息，提及“高工帮忙处理一下这个订单”。在他被宣告死亡8小时后，当天21:09，他的微信又收到了一条私聊，称“周一一早有急任务，今天验货不过，要把这个改下”。

李女士认为，高广辉是在工作时突发疾病后去世。决定书显示，他所在的公司已向广州市黄埔区人社局提交工伤认定申请，人社局已受理该申请。记者以市民身份询问工伤申请情况，工作人员称依据时间看，目前还未得出结果。

2025年高广辉猝死事件（资料摘录）
事件概况：2025年11月29日，年仅32岁的广州程序员高广辉在周末居家办公时突发不适，送医抢救无效死亡。事件引发了关于“居家加班”是否属于工伤的争议。
''';
