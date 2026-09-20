import { AppColors } from '../../../constants/AppColors';
import { AppDimens } from '../../../constants/AppDimens';
import { KnowledgeLevel, KnowledgeMetadata } from '../../../models/knowledge/KnowledgeMetadata';

/**
 * 知识卡片组件。
 *
 * 职责：以卡片形态展示单条知识元数据——主标题、分类、难度徽章、标签流与摘要概括；
 *      点击后通过回调把知识 id 上抛给父页面，由父页面负责路由跳转。
 * 分层约束：本组件只做渲染与事件上抛，不访问数据源、不自行跳转路由。
 */
@Component
export struct KnowledgeCard {
  /** 知识元数据实体 */
  @Prop item: KnowledgeMetadata = {
    id: '',
    title: '',
    category: '',
    // 空态哨兵对象：仅在 @Prop 默认值 / 兜底路径使用，永不进入渲染路径。
    // 联合类型收窄后 '' 不再合法，此处为已知契约的类型对齐断言。
    // 若未来此对象被意外渲染，须改为可空类型 + build() 判空分支（结构性重构）。
    level: '' as KnowledgeLevel,
    tags: [],
    summary: ''
  };
  /** 点击回调：上抛知识 id */
  onClickItem: (id: string) => void = () => {};

  build() {
    Column({ space: AppDimens.SPACING_SM }) {
      // 标题
      Text(this.item.title)
        .fontSize(AppDimens.FONT_SIZE_SUBTITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // 分类 + 难度徽章
      Row({ space: AppDimens.SPACING_SM }) {
        Text(this.item.category)
          .fontSize(AppDimens.FONT_SIZE_CAPTION)
          .fontColor(AppColors.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        Text(this.item.level)
          .fontSize(AppDimens.FONT_SIZE_CAPTION)
          .fontColor(AppColors.PRIMARY)
          .backgroundColor(AppColors.PRIMARY_LIGHT)
          .padding({
            left: AppDimens.SPACING_SM,
            right: AppDimens.SPACING_SM,
            top: AppDimens.SPACING_XS,
            bottom: AppDimens.SPACING_XS
          })
          .borderRadius(AppDimens.RADIUS_SM)
      }
      .width('100%')

      // 标签流
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.item.tags, (tag: string) => {
          Text(tag)
            .fontSize(AppDimens.FONT_SIZE_CAPTION)
            .fontColor(AppColors.TEXT_SECONDARY)
            .backgroundColor(AppColors.BACKGROUND)
            .padding({
              left: AppDimens.SPACING_SM,
              right: AppDimens.SPACING_SM,
              top: AppDimens.SPACING_XS,
              bottom: AppDimens.SPACING_XS
            })
            .borderRadius(AppDimens.RADIUS_SM)
            .margin({ right: AppDimens.SPACING_XS, bottom: AppDimens.SPACING_XS })
        }, (tag: string) => `${this.item.id}-${tag}`)
      }
      .width('100%')

      // 摘要概括
      Text(this.item.summary)
        .fontSize(AppDimens.FONT_SIZE_BODY)
        .fontColor(AppColors.TEXT_SECONDARY)
        .width('100%')
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(AppDimens.SPACING_LG)
    .backgroundColor(AppColors.SURFACE)
    .borderRadius(AppDimens.RADIUS_MD)
    .onClick(() => {
      this.onClickItem(this.item.id);
    })
  }
}
