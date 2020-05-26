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

import "./AuthorityIssuerData.sol";

// Claim Protocol Type (CPT) 数据合约
contract CptData {
    // CPT ID has been categorized into 3 zones: 0 - 999 are reserved for system CPTs,
    //  1000-2000000 for Authority Issuer's CPTs, and the rest for common WeIdentiy DIDs.

    // CPT ID 已分为3个区域：0-999为系统CPT保留，1000-2000000为Authority Issuer的CPT保留，其余为普通WeIdentiy DID。
    // todo 这部分具体参照: https://fintech.webank.com/developer/docs/weidentity/docs/weidentity-contract-design.html 中的 `WeIdentity CPT智能合约` 部分


    // 0 为非法的 CPT Id
    // 系统的CPT Id [1, 1000)
    // 权威发行者的CPT Id的起始位置 [1000, 2000000)
    uint constant public AUTHORITY_ISSUER_START_ID = 1000;
    // 普通 CPT Id的起始位置 [2000000, +∞)
    uint constant public NONE_AUTHORITY_ISSUER_START_ID = 2000000;

    // 记录当前最新的 cptId, 权威发行者
    uint private authority_issuer_current_id = 1000;
    // 记录当前最新的 cptId, 普通
    uint private none_authority_issuer_current_id = 2000000;


    // 权威发行者 数据合约
    AuthorityIssuerData private authorityIssuerData;


    // todo 构造函数
    function CptData(
        address authorityIssuerDataAddress
    ) 
        public
    {
        // 实例化
        authorityIssuerData = AuthorityIssuerData(authorityIssuerDataAddress);
    }


    // 签名结构的定义
    struct Signature {
        uint8 v; 
        bytes32 r; 
        bytes32 s;
    }


    // CPT 模板结构的定义
    struct Cpt {
        //store the weid address of cpt publisher
        //
        // 存储 cpt的发布者的 weId
        address publisher;

        //intArray[0] store cpt version, int[1] store created, int[2] store updated and left are  preserved int fields
        //
        // intArray[0] 存储库的cpt版本, int[1] 存储 create TimeStamp, int[2] 存储库 update TimeStamp, 剩下的是保留的int字段
        int[8] intArray; // int[8]{0<version>, createTimeStamp}

        //all are  preserved bytes32 fields
        //
        // 全部保留字节32个字段 bytes[8]{0,0,...,0}
        bytes32[8] bytes32Array;

        //store json schema
        //
        // 存储json模式,  cpt模板的json字符串
        bytes32[128] jsonSchemaArray;

        //store signature
        //
        // 存储 签名结构体
        Signature signature;
    }


    // 存储所有 已经发布了的 CPT 模板信息  todo  注意这里面的东西不会被删除
    // (cptId => Cpt)
    mapping (uint => Cpt) private cptMap;


    // 设置一个 新的 CPT 模板
    function putCpt(
        uint cptId,                         // cptId
        address cptPublisher,               // 发布该 cpt 模板的 个人或者机构的 WeId
        int[8] cptIntArray,                 // int[8]{0<version>, createTimeStamp}
        bytes32[8] cptBytes32Array,         // bytes32[8]{0,0,...,0}
        bytes32[128] cptJsonSchemaArray,    // bytes32[128]{} (cptjsonStr)

        // signature = sign(publisher|cptjsonStr)
        uint8 cptV,                         // 签名中的 V
        bytes32 cptR,                       // 签名中的 R
        bytes32 cptS                        // 签名中的 S
    ) 
        public 
        returns (bool) 
    {

        // 组装一个 signature 实例
        Signature memory cptSignature = Signature({v: cptV, r: cptR, s: cptS});

        // 组装一个 CPT模板 实例
        cptMap[cptId] = Cpt({publisher: cptPublisher, intArray: cptIntArray, bytes32Array: cptBytes32Array, jsonSchemaArray:cptJsonSchemaArray, signature: cptSignature});
        return true;
    }


    // 根据发布者的 WeId 获取新的 cptId
    function getCptId(
        address publisher
    ) 
        public 
        constant
        returns 
        (uint cptId)
    {

        // 判断该 发布者是否是 权威发行者
        if (authorityIssuerData.isAuthorityIssuer(publisher)) {

            // 遍历 当前最新 cptId, 并判断是否已经存在该 Cpt模板了
            // 已经存在则 叠加该 cptId 继续做判断, 一直算到一个没有最新模板的 cptId
            while (isCptExist(authority_issuer_current_id)) {
                authority_issuer_current_id++;
            }

            // 最新的 cptId, todo 注意看上面的 while, 可以知道这里再做 ++ 是对的, 不会算多
            cptId = authority_issuer_current_id++;


            // 如果当前 权威发行者的 cptId 已经到了  2000000
            // 则, 重置为 0, 0即为非法的 cptId
            // todo 正常不会有 200W 这么多 cpt模板的
            if (cptId >= NONE_AUTHORITY_ISSUER_START_ID) {
                cptId = 0;
            }


        } else { // 否则, 就是 普通的 cpt模板

            // 逻辑几乎合格上面一样, 叠加出 cptId
            while (isCptExist(none_authority_issuer_current_id)) {
                none_authority_issuer_current_id++;
            }
            cptId = none_authority_issuer_current_id++;
        }
    }

    function getCpt(
        uint cptId
    ) 
        public 
        constant 
        returns (
        address publisher, 
        int[8] intArray, 
        bytes32[8] bytes32Array,
        bytes32[128] jsonSchemaArray, 
        uint8 v, 
        bytes32 r, 
        bytes32 s) 
    {
        Cpt memory cpt = cptMap[cptId];
        publisher = cpt.publisher;
        intArray = cpt.intArray;
        bytes32Array = cpt.bytes32Array;
        jsonSchemaArray = cpt.jsonSchemaArray;
        v = cpt.signature.v;
        r = cpt.signature.r;
        s = cpt.signature.s;
    } 

    function getCptPublisher(
        uint cptId
    ) 
        public 
        constant 
        returns (address publisher)
    {
        Cpt memory cpt = cptMap[cptId];
        publisher = cpt.publisher;
    }

    function getCptIntArray(
        uint cptId
    ) 
        public 
        constant 
        returns (int[8] intArray)
    {
        Cpt memory cpt = cptMap[cptId];
        intArray = cpt.intArray;
    }

    function getCptJsonSchemaArray(
        uint cptId
    ) 
        public 
        constant 
        returns (bytes32[128] jsonSchemaArray)
    {
        Cpt memory cpt = cptMap[cptId];
        jsonSchemaArray = cpt.jsonSchemaArray;
    }

    function getCptBytes32Array(
        uint cptId
    ) 
        public 
        constant 
        returns (bytes32[8] bytes32Array)
    {
        Cpt memory cpt = cptMap[cptId];
        bytes32Array = cpt.bytes32Array;
    }

    function getCptSignature(
        uint cptId
    ) 
        public 
        constant 
        returns (uint8 v, bytes32 r, bytes32 s) 
    {
        Cpt memory cpt = cptMap[cptId];
        v = cpt.signature.v;
        r = cpt.signature.r;
        s = cpt.signature.s;
    }

    function isCptExist(
        uint cptId
    ) 
        public 
        constant 
        returns (bool)
    {
        int[8] memory intArray = getCptIntArray(cptId);
        if (intArray[0] != 0) {
            return true;
        } else {
            return false;
        }
    }
}