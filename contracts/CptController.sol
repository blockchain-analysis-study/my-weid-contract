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
        uint retCode, 
        uint cptId, 
        int cptVersion
    );

    // 更新 CPT 模板的 event
    event UpdateCptRetLog(
        uint retCode, 
        uint cptId, 
        int cptVersion
    );


    // todo 注册 CPT 模板信息
    function registerCpt(
        uint cptId,                         // 当前 CPT Id

        //
        address publisher,                  // 发布该 cpt 模板的 个人或者机构的 WeId
        int[8] intArray, 
        bytes32[8] bytes32Array,
        bytes32[128] jsonSchemaArray, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    )
        public
        returns (bool)
    {
        if (!weIdContract.isIdentityExist(publisher)) {
            RegisterCptRetLog(CPT_PUBLISHER_NOT_EXIST, 0, 0);
            return false;
        }
        if (cptData.isCptExist(cptId)) {
            RegisterCptRetLog(CPT_ALREADY_EXIST, cptId, 0);
            return false;
        }

        // Authority related checks. We use tx.origin here to decide the authority. For SDK
        // calls, publisher and tx.origin are normally the same. For DApp calls, tx.origin dictates.
        uint lowId = cptData.AUTHORITY_ISSUER_START_ID();
        uint highId = cptData.NONE_AUTHORITY_ISSUER_START_ID();
        if (cptId < lowId) {
            // Only committee member can create this, check initialization first
            if (internalRoleControllerAddress == 0x0) {
                RegisterCptRetLog(NO_PERMISSION, cptId, 0);
                return false;
            }
            if (!roleController.checkPermission(tx.origin, roleController.MODIFY_AUTHORITY_ISSUER())) {
                RegisterCptRetLog(NO_PERMISSION, cptId, 0);
                return false;
            }
        } else if (cptId < highId) {
            // Only authority issuer can create this, check initialization first
            if (internalRoleControllerAddress == 0x0) {
                RegisterCptRetLog(NO_PERMISSION, cptId, 0);
                return false;
            }
            if (!roleController.checkPermission(tx.origin, roleController.MODIFY_KEY_CPT())) {
                RegisterCptRetLog(NO_PERMISSION, cptId, 0);
                return false;
            }
        }

        int cptVersion = CPT_DEFAULT_VERSION;
        intArray[0] = cptVersion;
        cptData.putCpt(cptId, publisher, intArray, bytes32Array, jsonSchemaArray, v, r, s);

        RegisterCptRetLog(0, cptId, cptVersion);
        return true;
    }

    function registerCpt(
        address publisher, 
        int[8] intArray, 
        bytes32[8] bytes32Array,
        bytes32[128] jsonSchemaArray, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) 
        public 
        returns (bool) 
    {
        if (!weIdContract.isIdentityExist(publisher)) {
            RegisterCptRetLog(CPT_PUBLISHER_NOT_EXIST, 0, 0);
            return false;
        }

        uint cptId = cptData.getCptId(publisher); 
        if (cptId == 0) {
            RegisterCptRetLog(AUTHORITY_ISSUER_CPT_ID_EXCEED_MAX, 0, 0);
            return false;
        }
        int cptVersion = CPT_DEFAULT_VERSION;
        intArray[0] = cptVersion;
        cptData.putCpt(cptId, publisher, intArray, bytes32Array, jsonSchemaArray, v, r, s);

        RegisterCptRetLog(0, cptId, cptVersion);
        return true;
    }

    function updateCpt(
        uint cptId, 
        address publisher, 
        int[8] intArray, 
        bytes32[8] bytes32Array,
        bytes32[128] jsonSchemaArray, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) 
        public 
        returns (bool) 
    {
        if (!weIdContract.isIdentityExist(publisher)) {
            UpdateCptRetLog(CPT_PUBLISHER_NOT_EXIST, 0, 0);
            return false;
        }
        if (!roleController.checkPermission(tx.origin, roleController.MODIFY_AUTHORITY_ISSUER())
            && publisher != cptData.getCptPublisher(cptId)) {
            UpdateCptRetLog(NO_PERMISSION, 0, 0);
            return false;
        }
        if (cptData.isCptExist(cptId)) {
            int[8] memory cptIntArray = cptData.getCptIntArray(cptId);
            int cptVersion = cptIntArray[0] + 1;
            intArray[0] = cptVersion;
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
    mapping (uint => uint) credentialTemplateStored;
    event CredentialTemplate(
        uint cptId,
        bytes credentialPublicKey,
        bytes credentialProof
    );

    function putCredentialTemplate(
        uint cptId,
        bytes credentialPublicKey,
        bytes credentialProof
    )
        public
    {
        CredentialTemplate(cptId, credentialPublicKey, credentialProof);
        credentialTemplateStored[cptId] = block.number;
    }

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