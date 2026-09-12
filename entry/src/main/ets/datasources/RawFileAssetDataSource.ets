import resourceManager from '@ohos.resourceManager';
import { util } from '@kit.ArkTS';
import { ErrorCode } from '../models/common/ErrorCode';
import { Failure, Result, Success } from '../models/common/Result';
import { CodeSnippet } from '../models/knowledge/CodeSnippet';
import { KnowledgeContent, KnowledgeItem } from '../models/knowledge/KnowledgeItem';
import { KnowledgeMetadata } from '../models/knowledge/KnowledgeMetadata';

/**
 * 静态资产数据版本配置模型（对应 database/schema_version.json）。
 * 说明：该结构仅服务于 DataSource 内部的版本判定，不属于跨层业务模型，故就近声明于本文件。
 */
export interface SchemaVersion {
  schemaVersion: string;
  minAppVersion: string;
  maxAppVersion: string;
}

/**
 * 知识索引文件模型（对应 database/knowledge/index.json）。
 * 说明：属于资产文件的外层信封结构，仅用于本数据源解析，故就近声明于本文件。
 */
export interface KnowledgeIndex {
  schemaVersion: string;
  items: KnowledgeMetadata[];
}

/**
 * 内部错误载体（不对外暴露）。
 *
 * 存在原因（ArkTS 事实约束）：ArkTS 不支持结构化类型，无法把接口形式的
 * Result<T> 可辨识联合收窄为 Failure，因此 `if (!x.success) return x;` 会同时触发
 * 「Property 'code' does not exist on type 'Result<T>'」与跨泛型不可赋值错误。
 * 解决办法：内部流程一律不传递 Result<T> 联合类型，改用本载体携带失败信息；
 * 仅在公共方法出口处一次性组装为标准 Result<T>，从根本上规避联合类型收窄。
 */
class DataSourceError {
  code: ErrorCode;
  message: string;

  constructor(code: ErrorCode, message: string) {
    this.code = code;
    this.message = message;
  }
}

/**
 * 元素数组读取结果（内部专用）。
 * 用于区分「字段本身缺失」（正常，可选字段）与「字段存在但结构非法」（错误），
 * 避免借助 error 的既有取值做二次判断。
 */
class NumberArrayOutcome {
  /** 目标字段是否存在且合法 */
  readonly present: boolean;
  /** 解析出的数字数组；字段缺失时为 undefined */
  readonly values: number[] | undefined;

  constructor(present: boolean, values: number[] | undefined) {
    this.present = present;
    this.values = values;
  }
}

/**
 * 原始文件资产数据源。
 *
 * 职责：唯一负责 rawfile 静态资产的底层读取、UTF-8 解码、JSON 解析与防御性字段校验，
 *      并以 Result<T> 形式向上层返回结构化结果或语义化 ErrorCode。
 * 分层约束：
 *  - 本层是四层架构的最底层（DataSource），禁止承担缓存、聚合等 Repository 职责。
 *  - 依赖通过构造函数注入 ResourceManager，严禁在类内部自行获取 Context。
 *  - 所有异常必须在方法内被拦截并转换为 Result.Failure，严禁向调用方裸抛异常。
 * 类型安全约定：
 *  - 对外返回类型为架构规定的 Result<T>（Success | Failure 联合类型）。
 *  - 内部解析链路禁止传递、判断、收窄 Result<T> 联合类型，失败信息统一经 DataSourceError 传递，
 *    解析成功值统一以「是否为 undefined」判定，故全程不需要任何联合类型收窄。
 *  - JSON 取值必须经过 typeof / Array.isArray 显式字段检查，严禁 "as Model" 断言。
 * 路径约束：所有 rawfile 路径均为相对 rawfile 根目录的相对路径，
 *          严禁出现 'resources/rawfile/' 前缀，严禁以 '/' 开头。
 */
export class RawFileAssetDataSource {
  /** 当前应用版本号，用于与资产声明的最低/最高兼容版本做双向判定。 */
  private static readonly CURRENT_APP_VERSION: string = '1.0.0';
  /** 版本配置资产路径（相对 rawfile 根目录）。 */
  private static readonly PATH_SCHEMA_VERSION: string = 'database/schema_version.json';
  /** 知识索引资产路径（相对 rawfile 根目录）。 */
  private static readonly PATH_KNOWLEDGE_INDEX: string = 'database/knowledge/index.json';
  /** 知识详情资产路径前缀（相对 rawfile 根目录）。 */
  private static readonly PATH_KNOWLEDGE_DETAIL_PREFIX: string = 'database/knowledge/details/';
  /** 知识详情资产扩展名。 */
  private static readonly EXT_JSON: string = '.json';

  private readonly resourceMgr: resourceManager.ResourceManager;

  /**
   * @param resourceMgr 由上层 Provider 注入的系统资源管理器实例
   */
  constructor(resourceMgr: resourceManager.ResourceManager) {
    this.resourceMgr = resourceMgr;
  }

  /**
   * 读取并校验静态资产版本配置。
   * 双向判定：应用版本低于 minAppVersion，或主版本超出 maxAppVersion 兼容区间，即判定不兼容。
   * @returns 版本配置实体；不兼容或资产损坏时返回对应 Failure
   */
  async readSchemaVersion(): Promise<Result<SchemaVersion>> {
    const error: DataSourceError | undefined = new DataSourceError(ErrorCode.UNKNOWN, '');
    const text: string | undefined = await this.readRawFileText(RawFileAssetDataSource.PATH_SCHEMA_VERSION, error);
    if (text === undefined) {
      return RawFileAssetDataSource.toResultFailure<SchemaVersion>(error);
    }
    const schema: SchemaVersion | undefined = RawFileAssetDataSource.parseSchemaVersion(text, error);
    if (schema === undefined) {
      return RawFileAssetDataSource.toResultFailure<SchemaVersion>(error);
    }
    if (!RawFileAssetDataSource.isVersionCompatible(schema)) {
      return RawFileAssetDataSource.failure<SchemaVersion>(
        ErrorCode.DATA_VERSION_UNSUPPORTED,
        `app ${RawFileAssetDataSource.CURRENT_APP_VERSION} is out of asset compatibility range `
          + `[${schema.minAppVersion}, ${schema.maxAppVersion}]`
      );
    }
    return RawFileAssetDataSource.success<SchemaVersion>(schema);
  }

  /**
   * 读取知识索引元数据列表（轻量，不含正文）。
   * @returns 元数据数组；资产缺失、JSON 损坏或字段缺失时返回对应 Failure
   */
  async readKnowledgeMetadataList(): Promise<Result<KnowledgeMetadata[]>> {
    const error: DataSourceError = new DataSourceError(ErrorCode.UNKNOWN, '');
    const text: string | undefined = await this.readRawFileText(RawFileAssetDataSource.PATH_KNOWLEDGE_INDEX, error);
    if (text === undefined) {
      return RawFileAssetDataSource.toResultFailure<KnowledgeMetadata[]>(error);
    }
    const items: KnowledgeMetadata[] | undefined =
      RawFileAssetDataSource.parseKnowledgeIndex(text, error);
    if (items === undefined) {
      return RawFileAssetDataSource.toResultFailure<KnowledgeMetadata[]>(error);
    }
    return RawFileAssetDataSource.success<KnowledgeMetadata[]>(items);
  }

  /**
   * 读取单篇知识详情正文（按需加载）。
   * @param id 知识条目唯一标识
   * @returns 知识详情实体；资产缺失、JSON 损坏或字段缺失时返回对应 Failure
   */
  async readKnowledgeItem(id: string): Promise<Result<KnowledgeItem>> {
    const error: DataSourceError = new DataSourceError(ErrorCode.UNKNOWN, '');
    const path: string = RawFileAssetDataSource.PATH_KNOWLEDGE_DETAIL_PREFIX
      + id + RawFileAssetDataSource.EXT_JSON;
    const text: string | undefined = await this.readRawFileText(path, error);
    if (text === undefined) {
      return RawFileAssetDataSource.toResultFailure<KnowledgeItem>(error);
    }
    const item: KnowledgeItem | undefined = RawFileAssetDataSource.parseKnowledgeItem(text, error);
    if (item === undefined) {
      return RawFileAssetDataSource.toResultFailure<KnowledgeItem>(error);
    }
    return RawFileAssetDataSource.success<KnowledgeItem>(item);
  }

  /**
   * 底层读取与解码：读取 rawfile 字节流并解码为 UTF-8 文本。
   * 该方法不解析 JSON，仅负责 I/O 与解码，供三个读取方法复用。
   * @param path 相对 rawfile 根目录的相对路径
   * @param error 失败信息出参；失败时被写入具体 ErrorCode 与原因
   * @returns 解码后的文本；失败返回 undefined
   */
  private async readRawFileText(path: string, error: DataSourceError): Promise<string | undefined> {
    try {
      const bytes: Uint8Array = await this.resourceMgr.getRawFileContent(path);
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      return decoder.decodeToString(bytes);
    } catch (err) {
      const message: string = err instanceof Error ? err.message : `${err}`;
      error.code = ErrorCode.FILE_NOT_FOUND;
      error.message = `read rawfile failed: ${path} (${message})`;
      return undefined;
    }
  }

  /** 解析版本配置文件。 */
  private static parseSchemaVersion(jsonText: string, error: DataSourceError): SchemaVersion | undefined {
    const record: Record<string, Object> | undefined = RawFileAssetDataSource.parseJsonObject(jsonText, error);
    if (record === undefined) {
      return undefined;
    }
    const schemaVersion: string | undefined = RawFileAssetDataSource.readString(record, 'schemaVersion');
    const minAppVersion: string | undefined = RawFileAssetDataSource.readString(record, 'minAppVersion');
    const maxAppVersion: string | undefined = RawFileAssetDataSource.readString(record, 'maxAppVersion');
    if (schemaVersion === undefined || minAppVersion === undefined || maxAppVersion === undefined) {
      error.code = ErrorCode.FIELD_MISSING;
      error.message = 'schema_version.json misses required fields';
      return undefined;
    }
    const value: SchemaVersion = {
      schemaVersion: schemaVersion,
      minAppVersion: minAppVersion,
      maxAppVersion: maxAppVersion
    };
    return value;
  }

  /** 解析知识索引文件，逐条校验元数据必填字段。 */
  private static parseKnowledgeIndex(jsonText: string, error: DataSourceError): KnowledgeMetadata[] | undefined {
    const record: Record<string, Object> | undefined = RawFileAssetDataSource.parseJsonObject(jsonText, error);
    if (record === undefined) {
      return undefined;
    }
    const itemsValue: Object | undefined = record.items;
    if (itemsValue === undefined || !Array.isArray(itemsValue)) {
      error.code = ErrorCode.FIELD_MISSING;
      error.message = 'index.json items is not an array';
      return undefined;
    }
    const rawItems: Object[] = RawFileAssetDataSource.asObjectArray(itemsValue);
    const result: KnowledgeMetadata[] = [];
    for (let index: number = 0; index < rawItems.length; index++) {
      const metadata: KnowledgeMetadata | undefined =
        RawFileAssetDataSource.parseMetadata(rawItems[index], error);
      if (metadata === undefined) {
        return undefined;
      }
      result.push(metadata);
    }
    return result;
  }

  /** 解析单条知识元数据。 */
  private static parseMetadata(value: Object, error: DataSourceError): KnowledgeMetadata | undefined {
    if (!RawFileAssetDataSource.isRecord(value)) {
      error.code = ErrorCode.FIELD_MISSING;
      error.message = 'metadata entry is not an object';
      return undefined;
    }
    const record: Record<string, Object> = value as Record<string, Object>;
    const id: string | undefined = RawFileAssetDataSource.readString(record, 'id');
    const title: string | undefined = RawFileAssetDataSource.readString(record, 'title');
    const category: string | undefined = RawFileAssetDataSource.readString(record, 'category');
    const level: string | undefined = RawFileAssetDataSource.readString(record, 'level');
    const tags: string[] | undefined = RawFileAssetDataSource.readStringArray(record, 'tags');
    const summary: string | undefined = RawFileAssetDataSource.readString(record, 'summary');
    if (id === undefined || title === undefined || category === undefined
      || level === undefined || tags === undefined || summary === undefined) {
      error.code = ErrorCode.FIELD_MISSING;
      error.message = 'metadata entry misses required fields';
      return undefined;
    }
    const metadata: KnowledgeMetadata = {
      id: id,
      title: title,
      category: category,
      level: level,
      tags: tags,
      summary: summary
    };
    return metadata;
  }

  /** 解析完整知识详情，含教材化正文结构。 */
  private static parseKnowledgeItem(jsonText: string, error: DataSourceError): KnowledgeItem | undefined {
    const record: Record<string, Object> | undefined = RawFileAssetDataSource.parseJsonObject(jsonText, error);
    if (record === undefined) {
      return undefined;
    }
    const id: string | undefined = RawFileAssetDataSource.readString(record, 'id');
    const title: string | undefined = RawFileAssetDataSource.readString(record, 'title');
    const category: string | undefined = RawFileAssetDataSource.readString(record, 'category');
    const level: string | undefined = RawFileAssetDataSource.readString(record, 'level');
    const tags: string[] | undefined = RawFileAssetDataSource.readStringArray(record, 'tags');
    const summary: string | undefined = RawFileAssetDataSource.readString(record, 'summary');
    const images: string[] | undefined = RawFileAssetDataSource.readStringArray(record, 'images');
    const relatedProjectIds: string[] | undefined =
      RawFileAssetDataSource.readStringArray(record, 'relatedProjectIds');
    if (id === undefined || title === undefined || category === undefined || level === undefined
      || tags === undefined || summary === undefined || images === undefined || relatedProjectIds === undefined) {
      error.code = ErrorCode.FIELD_MISSING;
      error.message = 'knowledge detail misses required fields';
      return undefined;
    }
    const contentValue: Object | undefined = record.content;
    if (contentValue === undefined || !RawFileAssetDataSource.isRecord(contentValue)) {
      error.code = ErrorCode.FIELD_MISSING;
      error.message = 'knowledge detail content is not an object';
      return undefined;
    }
    const content: KnowledgeContent | undefined =
      RawFileAssetDataSource.parseContent(contentValue as Record<string, Object>, error);
    if (content === undefined) {
      return undefined;
    }
    const item: KnowledgeItem = {
      id: id,
      title: title,
      category: category,
      level: level,
      tags: tags,
      summary: summary,
      images: images,
      relatedProjectIds: relatedProjectIds,
      content: content
    };
    return item;
  }

  /** 解析教材化正文结构，example 复合字段必须齐备 language/code/description。 */
  private static parseContent(value: Record<string, Object>, error: DataSourceError): KnowledgeContent | undefined {
    const prerequisite: string | undefined = RawFileAssetDataSource.readString(value, 'prerequisite');
    const objective: string | undefined = RawFileAssetDataSource.readString(value, 'objective');
    const concept: string | undefined = RawFileAssetDataSource.readString(value, 'concept');
    const principle: string | undefined = RawFileAssetDataSource.readString(value, 'principle');
    const experiment: string | undefined = RawFileAssetDataSource.readString(value, 'experiment');
    const tips: string | undefined = RawFileAssetDataSource.readString(value, 'tips');
    const commonErrors: string | undefined = RawFileAssetDataSource.readString(value, 'commonErrors');
    const keyPoints: string[] | undefined = RawFileAssetDataSource.readStringArray(value, 'keyPoints');
    if (prerequisite === undefined || objective === undefined || concept === undefined || principle === undefined
      || experiment === undefined || tips === undefined || commonErrors === undefined || keyPoints === undefined) {
      error.code = ErrorCode.FIELD_MISSING;
      error.message = 'knowledge content misses required fields';
      return undefined;
    }
    const exampleValue: Object | undefined = value.example;
    if (exampleValue === undefined || !RawFileAssetDataSource.isRecord(exampleValue)) {
      error.code = ErrorCode.FIELD_MISSING;
      error.message = 'knowledge content example is not an object';
      return undefined;
    }
    const example: CodeSnippet | undefined =
      RawFileAssetDataSource.parseCodeSnippet(exampleValue as Record<string, Object>, error);
    if (example === undefined) {
      return undefined;
    }
    const content: KnowledgeContent = {
      prerequisite: prerequisite,
      objective: objective,
      concept: concept,
      principle: principle,
      example: example,
      experiment: experiment,
      tips: tips,
      commonErrors: commonErrors,
      keyPoints: keyPoints
    };
    return content;
  }

  /** 解析代码片段；highlightLines 为可选字段，缺失时不视为校验失败。 */
  private static parseCodeSnippet(value: Record<string, Object>, error: DataSourceError): CodeSnippet | undefined {
    const language: string | undefined = RawFileAssetDataSource.readString(value, 'language');
    const code: string | undefined = RawFileAssetDataSource.readString(value, 'code');
    const description: string | undefined = RawFileAssetDataSource.readString(value, 'description');
    if (language === undefined || code === undefined || description === undefined) {
      error.code = ErrorCode.FIELD_MISSING;
      error.message = 'code snippet misses language/code/description';
      return undefined;
    }
    const outcome: NumberArrayOutcome =
      RawFileAssetDataSource.readNumberArray(value, 'highlightLines', error);
    if (!outcome.present) {
      if (error.code === ErrorCode.FIELD_MISSING) {
        return undefined;
      }
      const plain: CodeSnippet = { language: language, code: code, description: description };
      return plain;
    }
    const highlightLines: number[] | undefined = outcome.values;
    if (highlightLines === undefined) {
      const plain: CodeSnippet = { language: language, code: code, description: description };
      return plain;
    }
    const highlighted: CodeSnippet = {
      language: language,
      code: code,
      description: description,
      highlightLines: highlightLines
    };
    return highlighted;
  }

  /** 将 JSON 文本解析为可按键索引的对象，非对象结构一律判定为 JSON_INVALID。 */
  private static parseJsonObject(jsonText: string, error: DataSourceError): Record<string, Object> | undefined {
    let parsed: Object;
    try {
      parsed = JSON.parse(jsonText) as Object;
    } catch (err) {
      const message: string = err instanceof Error ? err.message : `${err}`;
      error.code = ErrorCode.JSON_INVALID;
      error.message = `JSON.parse failed (${message})`;
      return undefined;
    }
    if (!RawFileAssetDataSource.isRecord(parsed)) {
      error.code = ErrorCode.JSON_INVALID;
      error.message = 'JSON root is not an object';
      return undefined;
    }
    return parsed as Record<string, Object>;
  }

  /**
   * 版本双向判定：应用版本不得低于资产要求的最低版本，且主版本必须落在声明的兼容区间内。
   * 说明：maxAppVersion 采用 "1.x" 形式表示主版本兼容区间，故此处比较主版本号。
   */
  private static isVersionCompatible(schema: SchemaVersion): boolean {
    const appVersion: string = RawFileAssetDataSource.CURRENT_APP_VERSION;
    if (RawFileAssetDataSource.compareVersion(appVersion, schema.minAppVersion) < 0) {
      return false;
    }
    const maxMajor: number = RawFileAssetDataSource.parseMajor(schema.maxAppVersion);
    if (maxMajor >= 0 && RawFileAssetDataSource.parseMajor(appVersion) > maxMajor) {
      return false;
    }
    return true;
  }

  /** 按点分十进制比较版本号，返回 -1/0/1。 */
  private static compareVersion(left: string, right: string): number {
    const leftParts: string[] = left.split('.');
    const rightParts: string[] = right.split('.');
    const size: number = Math.max(leftParts.length, rightParts.length);
    for (let index: number = 0; index < size; index++) {
      const leftValue: number = RawFileAssetDataSource.parseVersionSegment(leftParts, index);
      const rightValue: number = RawFileAssetDataSource.parseVersionSegment(rightParts, index);
      if (leftValue > rightValue) {
        return 1;
      }
      if (leftValue < rightValue) {
        return -1;
      }
    }
    return 0;
  }

  /** 取版本号第 index 段的数值；缺失或非数字统一按 0 处理。 */
  private static parseVersionSegment(parts: string[], index: number): number {
    if (index >= parts.length) {
      return 0;
    }
    const segment: number = Number.parseInt(parts[index], 10);
    return Number.isNaN(segment) ? 0 : segment;
  }

  /** 解析版本主版本号；"1.x" 取 1，无法解析返回 -1 表示不做上限约束。 */
  private static parseMajor(version: string): number {
    const major: number = Number.parseInt(version.split('.')[0], 10);
    return Number.isNaN(major) ? -1 : major;
  }

  /**
   * 判断值是否为可按键索引的非数组对象。
   * 说明：ArkTS 不支持类型谓词（arkts-no-is），故仅做结构判定，
   *      调用方在判定通过后使用 as 完成基础静态类型对齐。
   */
  private static isRecord(value: Object | undefined): boolean {
    return value !== undefined && value !== null && typeof value === 'object' && !Array.isArray(value);
  }

  /** 将已确认的数组安全复制为 Object[]，替代被 ArkTS 限制的 Object.assign。 */
  private static asObjectArray(value: Object): Object[] {
    if (!Array.isArray(value)) {
      return [];
    }
    const source: Object[] = value as Object[];
    const copy: Object[] = [];
    for (let index: number = 0; index < source.length; index++) {
      copy.push(source[index]);
    }
    return copy;
  }

  /** 读取必填字符串字段；缺失或类型不符返回 undefined，绝不使用未校验断言。 */
  private static readString(record: Record<string, Object>, field: string): string | undefined {
    const value: Object | undefined = record[field];
    if (typeof value !== 'string') {
      return undefined;
    }
    const text: string = value;
    return text;
  }

  /** 读取必填字符串数组字段；缺失、非数组或含非字符串元素均返回 undefined。 */
  private static readStringArray(record: Record<string, Object>, field: string): string[] | undefined {
    const value: Object | undefined = record[field];
    if (value === undefined || !Array.isArray(value)) {
      return undefined;
    }
    const raw: Object[] = RawFileAssetDataSource.asObjectArray(value);
    const result: string[] = [];
    for (let index: number = 0; index < raw.length; index++) {
      const element: Object = raw[index];
      if (typeof element !== 'string') {
        return undefined;
      }
      const text: string = element;
      result.push(text);
    }
    return result;
  }

  /**
   * 读取可选数字数组字段。
   * 字段缺失属正常情况（present = false 且不写入 error）；
   * 字段存在但结构非法时写入 FIELD_MISSING 并返回 present = false。
   */
  private static readNumberArray(record: Record<string, Object>, field: string,
    error: DataSourceError): NumberArrayOutcome {
    const value: Object | undefined = record[field];
    if (value === undefined || value === null) {
      return new NumberArrayOutcome(false, undefined);
    }
    if (!Array.isArray(value)) {
      error.code = ErrorCode.FIELD_MISSING;
      error.message = `field ${field} is not an array`;
      return new NumberArrayOutcome(false, undefined);
    }
    const raw: Object[] = RawFileAssetDataSource.asObjectArray(value);
    const result: number[] = [];
    for (let index: number = 0; index < raw.length; index++) {
      const element: Object = raw[index];
      if (typeof element !== 'number') {
        error.code = ErrorCode.FIELD_MISSING;
        error.message = `field ${field} contains non-number element`;
        return new NumberArrayOutcome(false, undefined);
      }
      const numeric: number = element;
      result.push(numeric);
    }
    return new NumberArrayOutcome(true, result);
  }

  /** 构造成功结果。 */
  private static success<T>(data: T): Result<T> {
    const value: Success<T> = { success: true, data: data };
    return value;
  }

  /** 构造失败结果。 */
  private static failure<T>(code: ErrorCode, error: string): Result<T> {
    const value: Failure = { success: false, error: error, code: code };
    return value;
  }

  /** 在公共方法出口将内部错误载体转换为标准 Result 失败分支。 */
  private static toResultFailure<T>(error: DataSourceError): Result<T> {
    return RawFileAssetDataSource.failure<T>(error.code, error.message);
  }
}
