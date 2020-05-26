pragma solidity ^0.4.4;
/*
 *       Copyright© (2018-2019) WeBank Co., Ltd.
 *
 *       This file is part of weidentity-contract.
 *
 *       weidentity-contract is free software: you can redistribute it and/or modify
 *       it under the terms of the GNU Lesser General Public License as published by
 *       the Free Software Foundation, either version 3 of the License, or
 *       (at your option) any later version.
 *
 *       weidentity-contract is distributed in the hope that it will be useful,
 *       but WITHOUT ANY WARRANTY; without even the implied warranty of
 *       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *       GNU Lesser General Public License for more details.
 *
 *       You should have received a copy of the GNU Lesser General Public License
 *       along with weidentity-contract.  If not, see <https://www.gnu.org/licenses/>.
 */

import "./CptData.sol";
import "./WeIdContract.sol";
import "./RoleController.sol";

// Claim Protocol Type (CPT) 流程控制合约
contract CptController {

    // Error codes
    //
    // 一些 错误码
    uint constant private CPT_NOT_EXIST = 500301;
    uint constant private AUTHORITY_ISSUER_CPT_ID_EXCEED_MAX = 500302;
    uint constant private CPT_PUBLISHER_NOT_EXIST = 500303;
    uint constant private CPT_ALREADY_EXIST = 500304;
    uint constant private NO_PERMISSION = 500305;

    // Default CPT version
    //
    // 默认的 CPT 版本
    int constant private CPT_DEFAULT_VERSION = 1;


    // CPT 数据合约
    CptData private cptData;

    // WeId合约
    WeIdContract private weIdContract;

    // 权限控制合约
    RoleController private roleController;

    // Reserved for contract owner check
    //
    // 保留给 合约所有者 检查

    // 这个是对应的 role 合约的地址
    address private internalRoleControllerAddress;

    // 部署当前合约的 msg.sender
    address private owner;


    // todo 构造函数
    function CptController(
        address cptDataAddress,
        address weIdContractAddress
    ) 
        public
    {

        // 设置 owner 为 msg.sender
        owner = msg.sender;

        // 实例化
        cptData = CptData(cptDataAddress);
        // 实例化
        weIdContract = WeIdContract(weIdContractAddress);
    }


    // 设置对应的 role合约地址
    function setRoleController(
        address roleControllerAddress
    )
        public
    {

        // todo 只有 msg.sender 是 当前合约的 owner 时 且 入参的role合约地址不为空时
        // 校验才通过
        if (msg.sender != owner || roleControllerAddress == 0x0) {
            return;
        }

        // 实例化 role合约
        roleController = RoleController(roleControllerAddress);
        if (roleController.ROLE_ADMIN() <= 0) { // 其实这一句 一般不会走的
            return;
        }

        // 记录 role 合约的地址
        internalRoleControllerAddress = roleControllerAddress;
    }


    // 注册CPT 模板的 event
    event RegisterCptRetLog(
        uint retCode,   // 操作结果状态码, 0 成功, 其他失败
        uint cptId,     // cptId
        int cptVersion  // cpt version
    );

    // 更新 CPT 模板的 event
    event UpdateCptRetLog(
        uint retCode, 
        uint cptId, 
        int cptVersion
    );


    // todo 注册 CPT 模板信息 (方法重载)  主要留给注册 系统级别的 CPT模板用 或者 权威发行者 代理调用 设置CPT
    function registerCpt(
        uint cptId,                          // 当前 CPT Id

        address publisher,                   // 发布该 cpt 模板的 个人或者机构的 WeId
        int[8] intArray,                     // int[8]{0<version>, createTimeStamp}
        bytes32[8] bytes32Array,             // bytes32[8]{0,0,...,0}
        bytes32[128] jsonSchemaArray,        // bytes32[128]{} (cptjsonStr)

        // signature = sign(publisher|cptjsonStr)
        uint8 v,                             // 签名中的 V
        bytes32 r,                           // 签名中的 R
        bytes32 s                            // 签名中的 S
    )
        public
        returns (bool)
    {
        // 先判断, 当前 发布者的WeId是否存在
        if (!weIdContract.isIdentityExist(publisher)) {
            RegisterCptRetLog(CPT_PUBLISHER_NOT_EXIST, 0, 0);
            return false;
        }

        // 校验当前 cptId 是否已经存在
        if (cptData.isCptExist(cptId)) {
            RegisterCptRetLog(CPT_ALREADY_EXIST, cptId, 0);
            return false;
        }

        // Authority related checks. We use tx.origin here to decide the authority. For SDK
        // calls, publisher and tx.origin are normally the same. For DApp calls, tx.origin dictates.
        //
        // 权限相关检查。 我们在这里使用tx.origin来确定权限。
        // 对于SDK调用，publisher和tx.origin通常是相同的。
        // 对于DApp调用，由tx.origin指示
        uint lowId = cptData.AUTHORITY_ISSUER_START_ID();           // 这里的这个值是 1000
        uint highId = cptData.NONE_AUTHORITY_ISSUER_START_ID();     // 这里的这个值是 200W

        // 如果 当前 cptId 小于 1000, 则这是 系统级别的 cpt模板设置
        if (cptId < lowId) {
            // Only committee member can create this, check initialization first
            //
            // 只有委员会成员才能创建此文件，请先检查初始化
            if (internalRoleControllerAddress == 0x0) {
                RegisterCptRetLog(NO_PERMISSION, cptId, 0);
                return false;
            }

            // 校验当前 tx的原始发送者 是否是 admin 或者委员会成员
            if (!roleController.checkPermission(tx.origin, roleController.MODIFY_AUTHORITY_ISSUER())) {
                RegisterCptRetLog(NO_PERMISSION, cptId, 0);
                return false;
            }
        } else if (cptId < highId) { // 否则, 是权威发行者 的 cpt
            // Only authority issuer can create this, check initialization first
            //
            // 只有 授权发行者 才能创建此文件，请先检查初始化
            if (internalRoleControllerAddress == 0x0) {
                RegisterCptRetLog(NO_PERMISSION, cptId, 0);
                return false;
            }

            // 校验 当前 tx的原始发送者 是否具备设置 CPT 模板
            if (!roleController.checkPermission(tx.origin, roleController.MODIFY_KEY_CPT())) {
                RegisterCptRetLog(NO_PERMISSION, cptId, 0);
                return false;
            }
        }

        // 设置 cpt 版本号, 默认先使用 默认的版本号
        int cptVersion = CPT_DEFAULT_VERSION;
        intArray[0] = cptVersion;

        // 设置一个新的 cpt 模板
        cptData.putCpt(cptId, publisher, intArray, bytes32Array, jsonSchemaArray, v, r, s);

        // 记录event
        RegisterCptRetLog(0, cptId, cptVersion);
        return true;
    }

    // todo 注册 CPT 模板信息 (方法重载)
    function registerCpt(
        address publisher,                          // 发布该 cpt 模板的 个人或者机构的 WeId
        int[8] intArray,                            // int[8]{0<version>, createTimeStamp}
        bytes32[8] bytes32Array,                    // bytes32[8]{0,0,...,0}
        bytes32[128] jsonSchemaArray,               // bytes32[128]{} (cptjsonStr)

        // signature = sign(publisher|cptjsonStr)
        uint8 v,                                    // 签名中的 V
        bytes32 r,                                  // 签名中的 R
        bytes32 s                                   // 签名中的 S
    ) 
        public 
        returns (bool) 
    {

        // 先判断, 当前 发布者的WeId是否存在
        if (!weIdContract.isIdentityExist(publisher)) {
            RegisterCptRetLog(CPT_PUBLISHER_NOT_EXIST, 0, 0);
            return false;
        }

        // 根据 发布者的 weId 获取 cptId
        uint cptId = cptData.getCptId(publisher);

        // 0, 标书非法的 cptId
        if (cptId == 0) {
            RegisterCptRetLog(AUTHORITY_ISSUER_CPT_ID_EXCEED_MAX, 0, 0);
            return false;
        }

        // 设置 cpt 版本号, 默认先使用 默认的版本号
        int cptVersion = CPT_DEFAULT_VERSION;

        // intArray[8]{version. createTime, updateTime, ...预留位}
        intArray[0] = cptVersion;

        // 设置一个新的 cpt 模板
        cptData.putCpt(cptId, publisher, intArray, bytes32Array, jsonSchemaArray, v, r, s);

        // 记录event
        RegisterCptRetLog(0, cptId, cptVersion);
        return true;
    }


    // 更新对应 cptId 的 cpt模板信息
    function updateCpt(
        uint cptId,                         // 当前 CPT Id
        address publisher,                  // 发布该 cpt 模板的 个人或者机构的 WeId
        int[8] intArray,                    // int[8]{0<version>, createTimeStamp}
        bytes32[8] bytes32Array,            // bytes32[8]{0,0,...,0}
        bytes32[128] jsonSchemaArray,       // bytes32[128]{} (cptjsonStr)

        // signature = sign(publisher|cptjsonStr)
        uint8 v,                            // 签名中的 V
        bytes32 r,                          // 签名中的 R
        bytes32 s                           // 签名中的 S
    ) 
        public 
        returns (bool) 
    {

        // 先判断, 当前 发布者的WeId是否存在
        if (!weIdContract.isIdentityExist(publisher)) {
            UpdateCptRetLog(CPT_PUBLISHER_NOT_EXIST, 0, 0);
            return false;
        }

        // 校验当前 tx的原始发送者 是否是 admin 或者委员会成员
        if (!roleController.checkPermission(tx.origin, roleController.MODIFY_AUTHORITY_ISSUER())

            // todo 本次发起修改请求的 发布者一定要是 cpt模板的原始 发布者 才有权限
            && publisher != cptData.getCptPublisher(cptId)) {
            UpdateCptRetLog(NO_PERMISSION, 0, 0);
            return false;
        }

        // 当前 cpt 模板信息是否存在
        if (cptData.isCptExist(cptId)) {

            // 读取 intArray[8]{version. createTime, updateTime, ...预留位} 信息
            int[8] memory cptIntArray = cptData.getCptIntArray(cptId);

            // 递增 版本号
            int cptVersion = cptIntArray[0] + 1;
            intArray[0] = cptVersion;

            // 使用旧的 createTimeStamp, 因为 createTime 不可能因为 udate 动作而变更吧
            int created = cptIntArray[1];
            intArray[1] = created;
            cptData.putCpt(cptId, publisher, intArray, bytes32Array, jsonSchemaArray, v, r, s);
            UpdateCptRetLog(0, cptId, cptVersion);
            return true;
        } else {
            UpdateCptRetLog(CPT_NOT_EXIST, 0, 0);
            return false;
        }
    }

    function queryCpt(
        uint cptId
    ) 
        public 
        constant 
        returns (
        address publisher, 
        int[] intArray, 
        bytes32[] bytes32Array,
        bytes32[] jsonSchemaArray, 
        uint8 v, 
        bytes32 r, 
        bytes32 s)
    {
        publisher = cptData.getCptPublisher(cptId);
        intArray = getCptDynamicIntArray(cptId);
        bytes32Array = getCptDynamicBytes32Array(cptId);
        jsonSchemaArray = getCptDynamicJsonSchemaArray(cptId);
        (v, r, s) = cptData.getCptSignature(cptId);
    }

    function getCptDynamicIntArray(
        uint cptId
    ) 
        public
        constant 
        returns (int[])
    {
        int[8] memory staticIntArray = cptData.getCptIntArray(cptId);
        int[] memory dynamicIntArray = new int[](8);
        for (uint i = 0; i < 8; i++) {
            dynamicIntArray[i] = staticIntArray[i];
        }
        return dynamicIntArray;
    }

    function getCptDynamicBytes32Array(
        uint cptId
    ) 
        public 
        constant 
        returns (bytes32[])
    {
        bytes32[8] memory staticBytes32Array = cptData.getCptBytes32Array(cptId);
        bytes32[] memory dynamicBytes32Array = new bytes32[](8);
        for (uint i = 0; i < 8; i++) {
            dynamicBytes32Array[i] = staticBytes32Array[i];
        }
        return dynamicBytes32Array;
    }

    function getCptDynamicJsonSchemaArray(
        uint cptId
    ) 
        public 
        constant 
        returns (bytes32[])
    {
        bytes32[128] memory staticBytes32Array = cptData.getCptJsonSchemaArray(cptId);
        bytes32[] memory dynamicBytes32Array = new bytes32[](128);
        for (uint i = 0; i < 128; i++) {
            dynamicBytes32Array[i] = staticBytes32Array[i];
        }
        return dynamicBytes32Array;
    }

    //store the cptId and blocknumber
    //
    // 当存储了 (第三方) credential 模板时, 才会存储的 cptId => blockNumber
    mapping (uint => uint) credentialTemplateStored;


    // 记录 存储第三方 credential 模板时的event
    event CredentialTemplate(
        uint cptId,
        bytes credentialPublicKey,
        bytes credentialProof
    );


    // 设置 Credential 模板  if the cpt is not zkp type, no need to make template.
    //
    // 主要是  第三方 Credential 模板发布者给的pubKey 和 零知识 proof todo <模板信息在 proof中??>
    //
    // todo 注意, 我们一般在 注册了 cpt模板 (调用 registerCpt()) 之后, 需要根据该 CPT 模板的 type 是 original 还是 zkp 决定是否继续轻轻第三方 credential 模板, 并记录相关 zkp信息
    function putCredentialTemplate(
        uint cptId,                     // 当前 credential 模板的 claim 模板 Id
        bytes credentialPublicKey,      // credential 发行方给的 零知识证明的pubkey
        bytes credentialProof           // credential 发行方给的 当前 credential 的零知识证明
    )
        public
    {

        // 记录 credential 模板的 pubKey 和 零知识证明 proof
        CredentialTemplate(cptId, credentialPublicKey, credentialProof);
        credentialTemplateStored[cptId] = block.number;
    }

    // 根据 cptId 获取 credential 模板设置时的 blockNumber
    function getCredentialTemplateBlock(
        uint cptId
    )
        public
        constant
        returns(uint)
    {
        return credentialTemplateStored[cptId];
    }
}